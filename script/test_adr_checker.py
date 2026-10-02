#!/usr/bin/env python3
"""Contract tests for the repository-owned ADR checker.

The fixtures are real, temporary Git repositories. They intentionally construct
catalogs and baselines independently of the checker so the tests do not mirror
the production implementation.
"""

from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
CHECKER = REPO_ROOT / ".agents/skills/adr-management/scripts/adr_checker.py"
CANONICAL_WIKI = "https://github.com/joeroberts/release-radar.wiki.git"
DEVELOPMENT_REPOSITORY = "https://github.com/joeroberts/release-radar"
TICKET = "https://github.com/joeroberts/release-radar/issues/133"
OPERATION = "qa-contract-check"
SCOPE = "architecture.core"
ACCEPTED_CONTRACT_REVISION = "38cc05e4300df71faa16dfcdd234fe0f8cd46124"
INDEX_INTRODUCTION = (
    "Architecture decisions do not authorize work. Accepted status does not by "
    "itself establish current applicability, and historical records do not override "
    "current instructions."
)


def run(command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None,
        check: bool = True, input_bytes: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and completed.returncode != 0:
        raise AssertionError(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout: {completed.stdout.decode(errors='replace')}\n"
            f"stderr: {completed.stderr.decode(errors='replace')}"
        )
    return completed


def metadata(adr_id: str, status_value: str, *, implementation: str = "Recorded implementation fact.",
             qualification: str = "Exact recorded approval qualification.") -> bytes:
    return (
        "<!-- adr-metadata:v1 -->\n"
        f"- ID: {adr_id}\n"
        f"- Status: {status_value}\n"
        "- Date: 2026-10-02\n"
        "- Date meaning: Recorded decision date; not inferred from implementation.\n"
        f"- Implementation: {implementation}\n"
        f"- Approval qualification: {qualification}\n"
        "<!-- /adr-metadata:v1 -->\n"
    ).encode()


def document_bytes(adr_id: str, status_value: str, body: str = "\n## Decision\n\nKeep the boundary exact.\n") -> bytes:
    return metadata(adr_id, status_value) + body.encode()


def protected_body(document: bytes) -> bytes:
    marker = b"<!-- /adr-metadata:v1 -->\n"
    return document.split(marker, 1)[1]


def render_index(records: list[dict[str, object]]) -> bytes:
    rows = [
        INDEX_INTRODUCTION,
        "",
        "| ADR | Decision status |",
        "| --- | --- |",
    ]
    for record in sorted(records, key=lambda item: int(str(item["id"]).split("-")[1])):
        label = str(record["title"]).replace("\\", "\\\\").replace("|", "\\|")
        target = str(record["path"])[:-3]
        rows.append(f"| [{label}]({target}) | {record['status']} |")
    return ("\n".join(rows) + "\n").encode()


class WikiFixture:
    def __init__(self, root: Path, specs: list[dict[str, object]] | None = None) -> None:
        self.root = root
        self.remote = root / "wiki-remote.git"
        self.work = root / "wiki-work"
        self.env = os.environ.copy()
        self.env.update(
            {
                "GIT_CONFIG_COUNT": "1",
                "GIT_CONFIG_KEY_0": f"url.file://{self.remote}.insteadOf",
                "GIT_CONFIG_VALUE_0": CANONICAL_WIKI,
                "GIT_TERMINAL_PROMPT": "0",
            }
        )
        run(["git", "init", "--bare", "--initial-branch=main", str(self.remote)])
        run(["git", "init", "--initial-branch=main", str(self.work)])
        self.git("config", "user.name", "QA Fixture")
        self.git("config", "user.email", "qa@example.invalid")
        self.git("remote", "add", "origin", CANONICAL_WIKI)
        self.specs = specs or [
            {
                "id": "ADR-001",
                "path": "ADR-001-Core-Boundary.md",
                "title": "Core Boundary",
                "status": "Accepted",
                "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nKeep the boundary exact.\n",
            }
        ]
        self._build()

    def git(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
        return run(["git", *arguments], cwd=self.work, env=self.env, check=check)

    def write(self, relative: str, data: bytes) -> None:
        path = self.work / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-m", message)
        return self.rev("HEAD")

    def rev(self, revision: str) -> str:
        return self.git("rev-parse", revision).stdout.decode().strip()

    def blob(self, revision: str, path: str) -> str:
        return self.rev(f"{revision}:{path}")

    def push(self) -> None:
        self.git("push", "-u", "origin", "main")

    def _build(self) -> None:
        # Model the real cutover history: A is a legacy Wiki revision without a
        # catalog, B contains normalized ADR candidates, and C adds the catalog
        # and index whose accepted baselines point at B. Only C is published.
        for spec in self.specs:
            self.write(
                str(spec["path"]),
                (f"- Status: {spec['status']}\n\n## Decision\n\nLegacy source text.\n").encode(),
            )
        self.source_revision = self.commit("legacy ADR source without catalog")
        for spec in self.specs:
            doc = document_bytes(str(spec["id"]), str(spec["status"]), str(spec["body"]))
            self.write(str(spec["path"]), doc)
        self.baseline_revision = self.commit("accepted document candidates")

        records: list[dict[str, object]] = []
        for spec in self.specs:
            status_value = str(spec["status"])
            path = str(spec["path"])
            doc = (self.work / path).read_bytes()
            accepted = status_value in {"Accepted", "Superseded"}
            baseline = None
            if accepted:
                baseline = {
                    "commit": self.baseline_revision,
                    "path": path,
                    "blob": self.blob(self.baseline_revision, path),
                    "bodySha256": hashlib.sha256(protected_body(doc)).hexdigest(),
                }
            records.append(
                {
                    "id": spec["id"],
                    "path": path,
                    "title": spec["title"],
                    "status": status_value,
                    "domain": spec["domain"],
                    "scopes": spec["scopes"],
                    "blob": self.blob(self.baseline_revision, path),
                    "baseline": baseline,
                    "evidence": [TICKET],
                }
            )
        self.write_catalog(records)
        self.write("Architecture-Decisions.md", render_index(records))
        self.head = self.commit("catalog and derived index")
        self.push()

    def catalog(self) -> dict[str, object]:
        return json.loads((self.work / "ADR-Catalog.json").read_text())

    def write_catalog(self, records: list[dict[str, object]], **overrides: object) -> None:
        catalog: dict[str, object] = {
            "version": 1,
            "wikiRepository": CANONICAL_WIKI,
            "objectFormat": "sha1",
            "records": records,
        }
        catalog.update(overrides)
        self.write(
            "ADR-Catalog.json",
            (json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n").encode(),
        )

    def refresh_record_blob(self, adr_id: str) -> list[dict[str, object]]:
        records = list(self.catalog()["records"])
        for record in records:
            if record["id"] == adr_id:
                record["blob"] = self.git("hash-object", str(record["path"])).stdout.decode().strip()
        self.write_catalog(records)
        self.write("Architecture-Decisions.md", render_index(records))
        return records


class ADRCheckerContractTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="rr-adr-checker-qa-")
        self.addCleanup(self.temporary.cleanup)
        self.temp = Path(self.temporary.name)

    def fixture(self, specs: list[dict[str, object]] | None = None, name: str = "fixture") -> WikiFixture:
        return WikiFixture(self.temp / name, specs)

    def checker(self, fixture: WikiFixture, command: str, *arguments: str,
                expected_exit: int | None = None,
                parse_json: bool = True) -> tuple[subprocess.CompletedProcess[bytes], dict[str, object] | None]:
        self.assertTrue(CHECKER.is_file(), f"production checker is missing: {CHECKER}")
        completed = run(
            ["python3", str(CHECKER), command, *arguments],
            cwd=REPO_ROOT,
            env=fixture.env,
            check=False,
        )
        if expected_exit is not None:
            self.assertEqual(
                expected_exit,
                completed.returncode,
                completed.stderr.decode(errors="replace") or completed.stdout.decode(errors="replace"),
            )
        result = None
        if completed.stdout and parse_json:
            result = json.loads(completed.stdout)
        return completed, result

    def snapshot(self, fixture: WikiFixture, revision: str | None = None,
                 expected_exit: int = 0, ids: list[str] | None = None,
                 scopes: list[str] | None = None) -> dict[str, object]:
        args = [
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--revision", revision or fixture.head,
            "--ticket", TICKET,
            "--operation", OPERATION,
        ]
        for scope in scopes or [SCOPE]:
            args += ["--scope", scope]
        for adr_id in ids or ["ADR-001"]:
            args += ["--id", adr_id]
        completed, result = self.checker(fixture, "snapshot", *args, expected_exit=expected_exit)
        self.assertEqual(b"", completed.stderr)
        self.assertIsInstance(result, dict)
        return result  # type: ignore[return-value]

    def assert_blocked(self, result: dict[str, object], code: str) -> None:
        self.assertEqual("blocked", result["status"])
        diagnostics = result["diagnostics"]
        self.assertIsInstance(diagnostics, list)
        self.assertIn(code, {item["code"] for item in diagnostics})

    def test_valid_snapshot_returns_exact_result_envelope(self) -> None:
        fixture = self.fixture()
        result = self.snapshot(fixture)
        self.assertEqual(
            {
                "schemaVersion", "status", "ticket", "operation", "wikiRepository",
                "readRevision", "selectedIds", "scopes", "diagnostics", "exception",
            },
            set(result),
        )
        self.assertEqual("verified", result["status"])
        self.assertEqual(fixture.head, result["readRevision"])
        self.assertEqual(["ADR-001"], result["selectedIds"])
        self.assertEqual([SCOPE], result["scopes"])
        self.assertEqual([], result["diagnostics"])
        self.assertIsNone(result["exception"])

    def test_render_index_is_exact_two_column_markdown_and_does_not_mutate(self) -> None:
        specs = [
            {
                "id": "ADR-002", "path": "ADR-002-Earlier.md", "title": "Earlier Decision",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nEarlier.\n",
            },
            {
                "id": "ADR-010", "path": "ADR-010-Later.md", "title": "Later | Decision",
                "status": "Proposed", "domain": "development",
                "scopes": [{"key": "development.workflow", "applicability": "proposed"}],
                "body": "\n## Decision\n\nLater.\n",
            },
        ]
        fixture = self.fixture(specs)
        before = fixture.git("status", "--porcelain=v1").stdout
        completed, _ = self.checker(
            fixture,
            "render-index", "--repository", str(fixture.work), "--revision", fixture.head,
            expected_exit=0,
            parse_json=False,
        )
        after = fixture.git("status", "--porcelain=v1").stdout
        self.assertEqual(before, after)
        self.assertEqual(render_index(list(fixture.catalog()["records"])), completed.stdout)
        rendered = completed.stdout.decode()
        self.assertNotIn("Canonical record", rendered)
        self.assertNotIn("Implementation", rendered)
        self.assertNotIn("Approval qualification", rendered)

    def test_inventory_missing_and_uncatalogued_are_bidirectional(self) -> None:
        missing = self.fixture(name="missing")
        (missing.work / "ADR-001-Core-Boundary.md").unlink()
        missing.head = missing.commit("remove catalogued ADR")
        missing.push()
        self.assert_blocked(self.snapshot(missing, expected_exit=2), "ADR_MISSING")

        extra = self.fixture(name="extra")
        extra.write("ADR-002-Uncatalogued.md", document_bytes("ADR-002", "Proposed"))
        extra.head = extra.commit("add uncatalogued ADR")
        extra.push()
        self.assert_blocked(self.snapshot(extra, expected_exit=2), "ADR_UNCATALOGUED")

    def test_inventory_rejects_malformed_duplicate_id_and_unsafe_mode(self) -> None:
        malformed = self.fixture(name="malformed")
        malformed.write("ADR-bad.md", b"not an ADR\n")
        malformed.head = malformed.commit("malformed ADR candidate")
        malformed.push()
        self.assert_blocked(self.snapshot(malformed, expected_exit=2), "ADR_FORMAT_INVALID")

        duplicate = self.fixture(name="duplicate")
        duplicate.write("ADR-0001-Duplicate.md", document_bytes("ADR-0001", "Proposed"))
        duplicate.head = duplicate.commit("duplicate numeric ADR identity")
        duplicate.push()
        self.assert_blocked(self.snapshot(duplicate, expected_exit=2), "ADR_FORMAT_INVALID")

        executable = self.fixture(name="executable")
        path = executable.work / "ADR-001-Core-Boundary.md"
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        executable.head = executable.commit("unsafe executable ADR")
        executable.push()
        self.assert_blocked(self.snapshot(executable, expected_exit=2), "ADR_SOURCE_UNSAFE")

    def test_strict_catalog_rejects_unknown_duplicate_bom_invalid_utf8_and_wrong_type(self) -> None:
        cases: list[tuple[str, bytes]] = []
        base = {
            "version": 1,
            "wikiRepository": CANONICAL_WIKI,
            "objectFormat": "sha1",
            "records": [],
        }
        cases.append(("unknown", (json.dumps({**base, "unexpected": True}) + "\n").encode()))
        cases.append(("duplicate", b'{"version":1,"version":1,"wikiRepository":"' + CANONICAL_WIKI.encode() + b'","objectFormat":"sha1","records":[]}\n'))
        cases.append(("bom", b"\xef\xbb\xbf" + (json.dumps(base) + "\n").encode()))
        cases.append(("invalid-utf8", b"{\xff}\n"))
        cases.append(("wrong-type", (json.dumps({**base, "records": {}}) + "\n").encode()))
        cases.append(("record-missing-fields", (json.dumps({**base, "records": [{"id": "ADR-001"}]}) + "\n").encode()))
        valid_record = self.fixture(name="catalog-shape-source").catalog()["records"][0]
        cases.append(("record-wrong-field-type", (json.dumps({**base, "records": [{**valid_record, "id": 1}]}) + "\n").encode()))

        for index, (name, raw) in enumerate(cases):
            with self.subTest(name=name):
                fixture = self.fixture(name=f"catalog-{index}")
                fixture.write("ADR-Catalog.json", raw)
                fixture.head = fixture.commit(f"invalid catalog {name}")
                fixture.push()
                self.assert_blocked(self.snapshot(fixture, expected_exit=2), "ADR_FORMAT_INVALID")

    def test_metadata_grammar_and_size_limits_fail_closed(self) -> None:
        wrong_order = self.fixture(name="wrong-order")
        raw = (wrong_order.work / "ADR-001-Core-Boundary.md").read_bytes()
        raw = raw.replace(b"- Status: Accepted\n- Date:", b"- Date:", 1)
        wrong_order.write("ADR-001-Core-Boundary.md", raw)
        wrong_order.refresh_record_blob("ADR-001")
        wrong_order.head = wrong_order.commit("invalid metadata order")
        wrong_order.push()
        self.assert_blocked(self.snapshot(wrong_order, expected_exit=2), "ADR_FORMAT_INVALID")

        marker = self.fixture(name="body-marker")
        marker.write(
            "ADR-001-Core-Boundary.md",
            (marker.work / "ADR-001-Core-Boundary.md").read_bytes()
            + b"\n<!-- adr-metadata:v1 -->\n",
        )
        marker.refresh_record_blob("ADR-001")
        marker.head = marker.commit("marker inside body")
        marker.push()
        result = self.snapshot(marker, expected_exit=2)
        self.assertTrue(
            {"ADR_FORMAT_INVALID", "ADR_BODY_CHANGED"}
            & {item["code"] for item in result["diagnostics"]}
        )

        oversized = self.fixture(name="oversized")
        oversized.write("ADR-001-Core-Boundary.md", document_bytes("ADR-001", "Accepted", "\n" + "x" * (256 * 1024)))
        oversized.refresh_record_blob("ADR-001")
        oversized.head = oversized.commit("oversized ADR")
        oversized.push()
        self.assert_blocked(self.snapshot(oversized, expected_exit=2), "ADR_FORMAT_INVALID")

    def test_body_change_is_detected_even_when_current_blob_and_index_are_refreshed(self) -> None:
        fixture = self.fixture()
        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"Keep the boundary exact.", b"Change the accepted decision."))
        fixture.refresh_record_blob("ADR-001")
        fixture.head = fixture.commit("launder changed body through current blob")
        fixture.push()
        self.assert_blocked(self.snapshot(fixture, expected_exit=2), "ADR_BODY_CHANGED")

    def test_immutable_metadata_change_is_not_hidden_by_current_blob(self) -> None:
        fixture = self.fixture()
        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"Recorded implementation fact.", b"Invented new progress."))
        fixture.refresh_record_blob("ADR-001")
        fixture.head = fixture.commit("change immutable metadata")
        fixture.push()
        result = self.snapshot(fixture, expected_exit=2)
        self.assertTrue(
            {"ADR_BODY_CHANGED", "ADR_FORMAT_INVALID", "ADR_BLOB_MISMATCH"}
            & {item["code"] for item in result["diagnostics"]}
        )

    def test_index_mismatch_and_unresolved_scope_block(self) -> None:
        index = self.fixture(name="index")
        index.write("Architecture-Decisions.md", b"| ADR | Decision status |\n| --- | --- |\n")
        index.head = index.commit("break derived index")
        index.push()
        self.assert_blocked(self.snapshot(index, expected_exit=2), "ADR_INDEX_MISMATCH")

        unresolved = self.fixture(name="unresolved")
        catalog = unresolved.catalog()
        records = list(catalog["records"])
        records[0]["scopes"] = [{"key": SCOPE, "applicability": "unresolved"}]
        unresolved.write_catalog(records)
        unresolved.write("Architecture-Decisions.md", render_index(records))
        unresolved.head = unresolved.commit("record unresolved scope")
        unresolved.push()
        self.assert_blocked(self.snapshot(unresolved, expected_exit=2), "ADR_SCOPE_UNRESOLVED")

    def test_compatible_accepted_records_can_be_selected_together(self) -> None:
        specs = [
            {
                "id": "ADR-001", "path": "ADR-001-First.md", "title": "First",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nFirst compatible constraint.\n",
            },
            {
                "id": "ADR-002", "path": "ADR-002-Second.md", "title": "Second",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nSecond compatible constraint.\n",
            },
        ]
        fixture = self.fixture(specs)
        result = self.snapshot(fixture, ids=["ADR-001", "ADR-002"])
        self.assertEqual("verified", result["status"])
        self.assertEqual(["ADR-001", "ADR-002"], result["selectedIds"])

    def test_explicit_selected_id_must_cover_a_requested_scope(self) -> None:
        fixture = self.fixture()
        result = self.snapshot(
            fixture,
            ids=["ADR-001"],
            scopes=["different.scope"],
            expected_exit=2,
        )
        self.assert_blocked(result, "ADR_SCOPE_UNRESOLVED")

    def test_stale_and_unavailable_freshness_never_verify(self) -> None:
        fixture = self.fixture(name="stale")
        retained = fixture.head
        fixture.write("Home.md", b"new remote head\n")
        fixture.head = fixture.commit("advance remote")
        fixture.push()
        self.assert_blocked(self.snapshot(fixture, retained, expected_exit=2), "ADR_SNAPSHOT_STALE")

        unavailable = self.fixture(name="unavailable")
        shutil.rmtree(unavailable.remote)
        self.assert_blocked(self.snapshot(unavailable, expected_exit=2), "ADR_FRESHNESS_UNAVAILABLE")

    def write_json(self, name: str, value: object) -> Path:
        path = self.temp / name
        path.write_text(json.dumps(value, separators=(",", ":")) + "\n")
        return path

    def read_exception_record(self, issue_snapshot: dict[str, object]) -> dict[str, object]:
        comment = issue_snapshot["comments"][0]
        body = comment["body"]
        prefix = "```adr-exception-v1\n"
        self.assertTrue(body.startswith(prefix))
        self.assertTrue(body.endswith("```\n"))
        return json.loads(body[len(prefix):-4])

    def bind_exception_record(self, issue_snapshot: dict[str, object],
                              trusted: dict[str, object], record: dict[str, object]) -> None:
        block = (json.dumps(record, separators=(",", ":")) + "\n").encode()
        issue_snapshot["comments"][0]["body"] = (
            "```adr-exception-v1\n" + block.decode() + "```\n"
        )
        trusted["blockSha256"] = hashlib.sha256(block).hexdigest()

    def transition(self, fixture: WikiFixture, prior: str, candidate: str,
                   authorization: dict[str, object], expected_exit: int,
                   *, initial_catalog: bool = False) -> dict[str, object]:
        auth_path = self.write_json(f"authorization-{candidate[:8]}.json", authorization)
        extra = ["--initial-catalog"] if initial_catalog else []
        _, result = self.checker(
            fixture,
            "transition",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--prior-revision", prior,
            "--candidate-revision", candidate,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--authorization", str(auth_path),
            *extra,
            expected_exit=expected_exit,
        )
        self.assertIsInstance(result, dict)
        return result  # type: ignore[return-value]

    def authorization(self, prior: str, candidate: str, actions: list[str],
                      *, adr_id: str = "ADR-001") -> dict[str, object]:
        return {
            "version": 1,
            "ticket": TICKET,
            "operation": OPERATION,
            "priorRevision": prior,
            "candidateRevision": candidate,
            "changes": [{"id": adr_id, "actions": actions}],
            "approvalRef": "trusted-owner-handoff:qa-fixture",
        }

    def test_transition_uses_remote_head_as_prior_and_allows_unpublished_candidate(self) -> None:
        fixture = self.fixture()
        prior = fixture.head
        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"- Status: Accepted", b"- Status: Superseded"))
        records = fixture.refresh_record_blob("ADR-001")
        records[0]["status"] = "Superseded"
        records[0]["scopes"] = [{"key": SCOPE, "applicability": "historical"}]
        fixture.write_catalog(records)
        fixture.write("Architecture-Decisions.md", render_index(records))
        candidate = fixture.commit("candidate supersession")

        result = self.transition(
            fixture, prior, candidate,
            self.authorization(prior, candidate, ["status", "scopes"]),
            expected_exit=0,
        )
        self.assertEqual("verified", result["status"])

    def test_initial_catalog_cutover_requires_absent_prior_catalog_and_full_add_coverage(self) -> None:
        fixture = self.fixture(name="bootstrap")
        candidate = fixture.head
        prior = fixture.source_revision
        fixture.git("push", "--force", "origin", f"{prior}:main")
        authorization = self.authorization(prior, candidate, ["add"])
        result = self.transition(
            fixture,
            prior,
            candidate,
            authorization,
            expected_exit=0,
            initial_catalog=True,
        )
        self.assertEqual("verified", result["status"])

        missing_coverage = self.authorization(prior, candidate, [])
        result = self.transition(
            fixture,
            prior,
            candidate,
            missing_coverage,
            expected_exit=2,
            initial_catalog=True,
        )
        self.assert_blocked(result, "ADR_TRANSITION_UNAUTHORIZED")

        fixture.git("push", "--force", "origin", f"{candidate}:main")
        fixture.write("Home.md", b"later candidate\n")
        later = fixture.commit("candidate after catalog exists")
        after_catalog = self.authorization(candidate, later, [])
        result = self.transition(
            fixture,
            candidate,
            later,
            after_catalog,
            expected_exit=2,
            initial_catalog=True,
        )
        self.assert_blocked(result, "ADR_TRANSITION_UNAUTHORIZED")

    def test_normal_transition_requires_status_and_baseline_authorization_for_new_accepted_record(self) -> None:
        accepted = self.fixture(name="new-accepted")
        prior = accepted.head
        path = "ADR-002-New-Decision.md"
        proposed_raw = document_bytes("ADR-002", "Proposed", "\n## Decision\n\nNew boundary.\n")
        accepted.write(path, proposed_raw)
        proposed_candidate = accepted.commit("prepare proposed ADR candidate")
        proposed_blob = accepted.blob(proposed_candidate, path)
        accepted.write(path, document_bytes("ADR-002", "Accepted", "\n## Decision\n\nNew boundary.\n"))
        records = list(accepted.catalog()["records"])
        records.append({
            "id": "ADR-002",
            "path": path,
            "title": "New Decision",
            "status": "Accepted",
            "domain": "product",
            "scopes": [{"key": SCOPE, "applicability": "current"}],
            "blob": accepted.git("hash-object", path).stdout.decode().strip(),
            "baseline": {
                "commit": proposed_candidate,
                "path": path,
                "blob": proposed_blob,
                "bodySha256": hashlib.sha256(protected_body(proposed_raw)).hexdigest(),
            },
            "evidence": [TICKET],
        })
        accepted.write_catalog(records)
        accepted.write("Architecture-Decisions.md", render_index(records))
        candidate = accepted.commit("add accepted ADR")

        add_only = self.transition(
            accepted,
            prior,
            candidate,
            self.authorization(prior, candidate, ["add"], adr_id="ADR-002"),
            expected_exit=2,
        )
        self.assert_blocked(add_only, "ADR_TRANSITION_UNAUTHORIZED")

        explicitly_nonproposed = self.transition(
            accepted,
            prior,
            candidate,
            self.authorization(prior, candidate, ["add", "status", "baseline"], adr_id="ADR-002"),
            expected_exit=2,
        )
        self.assert_blocked(explicitly_nonproposed, "ADR_TRANSITION_UNAUTHORIZED")

        proposed = self.fixture(name="new-proposed")
        proposed_prior = proposed.head
        proposed_path = "ADR-002-Proposal.md"
        proposed.write(proposed_path, document_bytes("ADR-002", "Proposed", "\n## Decision\n\nCandidate only.\n"))
        proposed_records = list(proposed.catalog()["records"])
        proposed_records.append({
            "id": "ADR-002",
            "path": proposed_path,
            "title": "Proposal",
            "status": "Proposed",
            "domain": "product",
            "scopes": [{"key": SCOPE, "applicability": "proposed"}],
            "blob": proposed.git("hash-object", proposed_path).stdout.decode().strip(),
            "baseline": None,
            "evidence": [TICKET],
        })
        proposed.write_catalog(proposed_records)
        proposed.write("Architecture-Decisions.md", render_index(proposed_records))
        proposed_candidate_commit = proposed.commit("add proposed ADR")
        proposed_result = self.transition(
            proposed,
            proposed_prior,
            proposed_candidate_commit,
            self.authorization(proposed_prior, proposed_candidate_commit, ["add"], adr_id="ADR-002"),
            expected_exit=0,
        )
        self.assertEqual("verified", proposed_result["status"])

    def test_title_only_transition_is_proposed_body_or_rejected_not_remove(self) -> None:
        accepted = self.fixture(name="accepted-title")
        accepted_prior = accepted.head
        accepted_records = list(accepted.catalog()["records"])
        accepted_records[0]["title"] = "Renamed Accepted Decision"
        accepted.write_catalog(accepted_records)
        accepted.write("Architecture-Decisions.md", render_index(accepted_records))
        accepted_candidate = accepted.commit("rename accepted catalog title")
        disguised_remove = self.transition(
            accepted,
            accepted_prior,
            accepted_candidate,
            self.authorization(accepted_prior, accepted_candidate, ["remove"]),
            expected_exit=2,
        )
        self.assert_blocked(disguised_remove, "ADR_TRANSITION_UNAUTHORIZED")

        specs = [{
            "id": "ADR-001", "path": "ADR-001-Proposal.md", "title": "Proposal",
            "status": "Proposed", "domain": "product",
            "scopes": [{"key": SCOPE, "applicability": "proposed"}],
            "body": "\n## Decision\n\nCandidate only.\n",
        }]
        proposed = self.fixture(specs, name="proposed-title")
        proposed_prior = proposed.head
        proposed_records = list(proposed.catalog()["records"])
        proposed_records[0]["title"] = "Renamed Proposal"
        proposed.write_catalog(proposed_records)
        proposed.write("Architecture-Decisions.md", render_index(proposed_records))
        proposed_candidate = proposed.commit("rename proposed catalog title")
        proposed_result = self.transition(
            proposed,
            proposed_prior,
            proposed_candidate,
            self.authorization(proposed_prior, proposed_candidate, ["proposed-body"]),
            expected_exit=0,
        )
        self.assertEqual("verified", proposed_result["status"])

    def test_transition_rejects_unbound_change_and_stale_prior(self) -> None:
        fixture = self.fixture(name="unbound")
        prior = fixture.head
        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"- Status: Accepted", b"- Status: Superseded"))
        records = fixture.refresh_record_blob("ADR-001")
        records[0]["status"] = "Superseded"
        records[0]["scopes"] = [{"key": SCOPE, "applicability": "historical"}]
        fixture.write_catalog(records)
        fixture.write("Architecture-Decisions.md", render_index(records))
        candidate = fixture.commit("unbound transition")
        result = self.transition(
            fixture, prior, candidate,
            self.authorization(prior, candidate, ["status"]),
            expected_exit=2,
        )
        self.assert_blocked(result, "ADR_TRANSITION_UNAUTHORIZED")

        fixture.git("reset", "--hard", prior)
        fixture.write("Home.md", b"advance remote\n")
        advanced = fixture.commit("advance prior")
        fixture.push()
        stale_candidate = fixture.rev(prior)
        result = self.transition(
            fixture, prior, stale_candidate,
            self.authorization(prior, stale_candidate, []),
            expected_exit=2,
        )
        self.assert_blocked(result, "ADR_SNAPSHOT_STALE")
        self.assertNotEqual(prior, advanced)

    def test_transition_strict_authorization_rejects_unknown_and_duplicate_fields(self) -> None:
        fixture = self.fixture()
        prior = fixture.head
        fixture.write("Home.md", b"candidate\n")
        candidate = fixture.commit("candidate")

        unknown = self.authorization(prior, candidate, [])
        unknown["unexpected"] = True
        result = self.transition(fixture, prior, candidate, unknown, expected_exit=2)
        self.assert_blocked(result, "ADR_TRANSITION_UNAUTHORIZED")

        raw_path = self.temp / "duplicate-authorization.json"
        raw_path.write_text(
            '{"version":1,"version":1,"ticket":"' + TICKET
            + '","operation":"' + OPERATION + '","priorRevision":"' + prior
            + '","candidateRevision":"' + candidate
            + '","changes":[],"approvalRef":"trusted"}\n'
        )
        _, duplicate = self.checker(
            fixture,
            "transition",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--prior-revision", prior,
            "--candidate-revision", candidate,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--authorization", str(raw_path),
            expected_exit=2,
        )
        self.assertIsInstance(duplicate, dict)
        self.assert_blocked(duplicate, "ADR_TRANSITION_UNAUTHORIZED")  # type: ignore[arg-type]

    def exception_inputs(self, fixture: WikiFixture, revision: str,
                         failures: list[dict[str, object]],
                         *, exception_id: str = "qa-exception-1") -> tuple[dict[str, object], dict[str, object]]:
        exception_record = {
            "version": 1,
            "exceptionId": exception_id,
            "repository": DEVELOPMENT_REPOSITORY,
            "wikiRepository": CANONICAL_WIKI,
            "issue": TICKET,
            "operation": OPERATION,
            "scopes": [SCOPE],
            "failures": failures,
            "catalogBlob": fixture.blob(revision, "ADR-Catalog.json"),
            "indexBlob": fixture.blob(revision, "Architecture-Decisions.md"),
            "catalogRevision": revision,
            "reason": "The current record is unavailable during bounded repair.",
            "risk": "The retained decision may not reflect a later current publication.",
            "accountablePerson": "Repository owner",
            "expiresAt": (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "resolutionCriteria": "Restore ordinary ADR verification.",
            "approvalRef": "trusted-owner-handoff:qa-fixture",
        }
        block = (json.dumps(exception_record, separators=(",", ":")) + "\n").encode()
        comment = {
            "id": "5960064851",
            "url": f"{TICKET}#issuecomment-5960064851",
            "updatedAt": "2026-10-02T12:00:00Z",
            "body": "```adr-exception-v1\n" + block.decode() + "```\n",
        }
        issue_snapshot = {
            "version": 1,
            "issue": {"url": TICKET, "state": "OPEN", "body": "Owning issue."},
            "comments": [comment],
            "commentsComplete": True,
        }
        trusted = {
            "version": 1,
            "exceptionId": exception_id,
            "repository": DEVELOPMENT_REPOSITORY,
            "wikiRepository": CANONICAL_WIKI,
            "issue": TICKET,
            "operation": OPERATION,
            "commentId": comment["id"],
            "commentUpdatedAt": comment["updatedAt"],
            "blockSha256": hashlib.sha256(block).hexdigest(),
            "approvalRef": "trusted-owner-handoff:qa-fixture",
            "revokedOrResolvedIds": [],
        }
        return issue_snapshot, trusted

    def relied_on(self, fixture: WikiFixture, revision: str, path: str) -> dict[str, object]:
        raw = fixture.git("show", f"{revision}:{path}").stdout
        return {
            "commit": revision,
            "path": path,
            "blob": fixture.blob(revision, path),
            "bodySha256": hashlib.sha256(protected_body(raw)).hexdigest(),
        }

    def missing_exception_fixture(self, name: str = "exception") -> tuple[WikiFixture, dict[str, object], dict[str, object], dict[str, object]]:
        fixture = self.fixture(name=name)
        baseline_commit = fixture.baseline_revision
        baseline_blob = fixture.blob(baseline_commit, "ADR-001-Core-Boundary.md")
        body_sha = hashlib.sha256(
            protected_body((fixture.work / "ADR-001-Core-Boundary.md").read_bytes())
        ).hexdigest()
        (fixture.work / "ADR-001-Core-Boundary.md").unlink()
        fixture.head = fixture.commit("missing current ADR")
        fixture.push()
        diagnostics = self.snapshot(fixture, expected_exit=2)
        self.assert_blocked(diagnostics, "ADR_MISSING")

        issue_snapshot, trusted = self.exception_inputs(
            fixture,
            fixture.head,
            [
                {
                    "code": "ADR_MISSING",
                    "revision": fixture.head,
                    "path": "ADR-001-Core-Boundary.md",
                    "expectedBlob": baseline_blob,
                    "observedBlob": None,
                    "reliedOn": [
                        {
                            "commit": baseline_commit,
                            "path": "ADR-001-Core-Boundary.md",
                            "blob": baseline_blob,
                            "bodySha256": body_sha,
                        }
                    ],
                }
            ],
        )
        return fixture, diagnostics, issue_snapshot, trusted

    def exception(self, fixture: WikiFixture, diagnostics: dict[str, object],
                  issue_snapshot: dict[str, object], trusted: dict[str, object],
                  expected_exit: int, *, revision: str | None = None) -> dict[str, object]:
        checked_revision = revision or fixture.head
        diagnostics_path = self.write_json("diagnostics.json", diagnostics)
        issue_path = self.write_json("issue-snapshot.json", issue_snapshot)
        trusted_path = self.write_json("trusted-approval.json", trusted)
        _, result = self.checker(
            fixture,
            "exception",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--revision", checked_revision,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--diagnostics", str(diagnostics_path),
            "--issue-snapshot", str(issue_path),
            "--trusted-approval", str(trusted_path),
            expected_exit=expected_exit,
        )
        self.assertIsInstance(result, dict)
        return result  # type: ignore[return-value]

    def test_exact_missing_record_exception_reports_proceeding_not_verified(self) -> None:
        fixture, diagnostics, issue, trusted = self.missing_exception_fixture()
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=0)
        self.assertEqual("proceeding_under_exception", result["status"])
        self.assertNotEqual("verified", result["status"])
        self.assertEqual("qa-exception-1", result["exception"]["exceptionId"])

    def test_exception_expiry_uses_wall_clock_and_rejects_caller_time_override(self) -> None:
        fixture, diagnostics, issue, trusted = self.missing_exception_fixture("wall-clock")
        record = self.read_exception_record(issue)
        record["expiresAt"] = (
            datetime.now(timezone.utc) - timedelta(minutes=1)
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
        self.bind_exception_record(issue, trusted, record)
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
        self.assertTrue(any("expired" in item["message"].lower() for item in result["diagnostics"]))

        diagnostics_path = self.write_json("override-diagnostics.json", diagnostics)
        issue_path = self.write_json("override-issue.json", issue)
        trusted_path = self.write_json("override-trusted.json", trusted)
        completed, parsed = self.checker(
            fixture,
            "exception",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--revision", fixture.head,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--diagnostics", str(diagnostics_path),
            "--issue-snapshot", str(issue_path),
            "--trusted-approval", str(trusted_path),
            "--now", "2000-01-01T00:00:00Z",
            expected_exit=64,
        )
        self.assertIsNone(parsed)
        self.assertIn(b"unrecognized arguments", completed.stderr)

    def test_missing_exception_requires_that_records_exact_fixed_baseline(self) -> None:
        specs = [
            {
                "id": "ADR-001", "path": "ADR-001-Core-Boundary.md", "title": "Core Boundary",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nKeep the boundary exact.\n",
            },
            {
                "id": "ADR-002", "path": "ADR-002-Other.md", "title": "Other",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nA different accepted decision.\n",
            },
        ]
        fixture = self.fixture(specs, name="wrong-missing-baseline")
        nonbaseline_commit = fixture.head
        (fixture.work / "ADR-001-Core-Boundary.md").unlink()
        fixture.head = fixture.commit("missing current ADR")
        fixture.push()
        diagnostics = self.snapshot(fixture, expected_exit=2)
        expected = fixture.catalog()["records"][0]["baseline"]["blob"]
        failure = {
            "code": "ADR_MISSING",
            "revision": fixture.head,
            "path": "ADR-001-Core-Boundary.md",
            "expectedBlob": expected,
            "observedBlob": None,
            "reliedOn": [
                self.relied_on(fixture, nonbaseline_commit, "ADR-001-Core-Boundary.md"),
                self.relied_on(fixture, fixture.head, "ADR-002-Other.md"),
            ],
        }
        issue, trusted = self.exception_inputs(fixture, fixture.head, [failure])
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
        self.assertTrue(any(
            item["code"] == "ADR_TRANSITION_UNAUTHORIZED"
            and "reliedon" in item["message"].lower()
            for item in result["diagnostics"]
        ))

    def test_missing_exception_rejects_catalog_baseline_borrowed_from_another_adr(self) -> None:
        specs = [
            {
                "id": "ADR-001", "path": "ADR-001-Core-Boundary.md", "title": "Core Boundary",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nKeep the boundary exact.\n",
            },
            {
                "id": "ADR-002", "path": "ADR-002-Other.md", "title": "Other",
                "status": "Accepted", "domain": "product",
                "scopes": [{"key": SCOPE, "applicability": "current"}],
                "body": "\n## Decision\n\nA different accepted decision.\n",
            },
        ]
        fixture = self.fixture(specs, name="borrowed-missing-baseline")
        records = list(fixture.catalog()["records"])
        records[0]["baseline"] = dict(records[1]["baseline"])
        fixture.write_catalog(records)
        fixture.write("Architecture-Decisions.md", render_index(records))
        (fixture.work / "ADR-001-Core-Boundary.md").unlink()
        fixture.head = fixture.commit("borrow another ADR baseline for a missing record")
        fixture.push()
        diagnostics = self.snapshot(fixture, expected_exit=2)
        self.assert_blocked(diagnostics, "ADR_MISSING")
        self.assert_blocked(diagnostics, "ADR_BASELINE_UNAVAILABLE")
        failure = {
            "code": "ADR_MISSING",
            "revision": fixture.head,
            "path": "ADR-001-Core-Boundary.md",
            "expectedBlob": records[0]["blob"],
            "observedBlob": None,
            "reliedOn": [
                self.relied_on(fixture, records[1]["baseline"]["commit"], "ADR-002-Other.md"),
                self.relied_on(fixture, fixture.head, "ADR-002-Other.md"),
            ],
        }
        issue, trusted = self.exception_inputs(fixture, fixture.head, [failure])
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
        self.assertEqual("blocked", result["status"])

    def test_uncatalogued_exception_is_limited_to_exact_proposed_information(self) -> None:
        for index, status_value in enumerate(("Proposed", "Accepted")):
            with self.subTest(status=status_value):
                fixture = self.fixture(name=f"uncatalogued-{index}")
                path = "ADR-002-Uncatalogued.md"
                fixture.write(path, document_bytes("ADR-002", status_value))
                fixture.head = fixture.commit(f"add {status_value} uncatalogued ADR")
                fixture.push()
                diagnostics = self.snapshot(fixture, expected_exit=2)
                observed = fixture.blob(fixture.head, path)
                failure = {
                    "code": "ADR_UNCATALOGUED",
                    "revision": fixture.head,
                    "path": path,
                    "expectedBlob": None,
                    "observedBlob": observed,
                    "reliedOn": [
                        self.relied_on(fixture, fixture.head, "ADR-001-Core-Boundary.md"),
                        self.relied_on(fixture, fixture.head, path),
                    ],
                }
                issue, trusted = self.exception_inputs(fixture, fixture.head, [failure])
                expected_exit = 0 if status_value == "Proposed" else 2
                result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=expected_exit)
                expected_status = "proceeding_under_exception" if status_value == "Proposed" else "blocked"
                self.assertEqual(expected_status, result["status"])

    def test_blob_mismatch_exception_requires_unchanged_body_and_immutable_metadata(self) -> None:
        fixture = self.fixture(name="blob-mismatch")
        observed = fixture.blob(fixture.head, "ADR-001-Core-Boundary.md")
        wrong = fixture.blob(fixture.head, "Architecture-Decisions.md")
        records = list(fixture.catalog()["records"])
        records[0]["blob"] = wrong
        fixture.write_catalog(records)
        fixture.write("Architecture-Decisions.md", render_index(records))
        fixture.head = fixture.commit("leave a stale catalog blob")
        fixture.push()
        diagnostics = self.snapshot(fixture, expected_exit=2)
        self.assertEqual({"ADR_BLOB_MISMATCH"}, {item["code"] for item in diagnostics["diagnostics"]})
        failure = {
            "code": "ADR_BLOB_MISMATCH",
            "revision": fixture.head,
            "path": "ADR-001-Core-Boundary.md",
            "expectedBlob": wrong,
            "observedBlob": observed,
            "reliedOn": [self.relied_on(fixture, fixture.head, "ADR-001-Core-Boundary.md")],
        }
        issue, trusted = self.exception_inputs(fixture, fixture.head, [failure])
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=0)
        self.assertEqual("proceeding_under_exception", result["status"])

        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"Recorded implementation fact.", b"Changed immutable fact."))
        fixture.head = fixture.commit("change immutable accepted metadata")
        fixture.push()
        changed_diagnostics = self.snapshot(fixture, expected_exit=2)
        self.assert_blocked(changed_diagnostics, "ADR_BODY_CHANGED")
        changed_failure = dict(failure)
        changed_failure["revision"] = fixture.head
        changed_failure["observedBlob"] = fixture.blob(fixture.head, "ADR-001-Core-Boundary.md")
        changed_failure["reliedOn"] = [self.relied_on(fixture, fixture.head, "ADR-001-Core-Boundary.md")]
        changed_issue, changed_trusted = self.exception_inputs(fixture, fixture.head, [changed_failure])
        changed_result = self.exception(
            fixture, changed_diagnostics, changed_issue, changed_trusted, expected_exit=2,
        )
        self.assertEqual("blocked", changed_result["status"])

    def test_global_freshness_exceptions_bind_the_retained_catalog_and_all_consumed_adrs(self) -> None:
        for index, failure_code in enumerate(("ADR_SNAPSHOT_STALE", "ADR_FRESHNESS_UNAVAILABLE")):
            with self.subTest(code=failure_code):
                fixture = self.fixture(name=f"freshness-{index}")
                retained = fixture.head
                if failure_code == "ADR_SNAPSHOT_STALE":
                    fixture.write("Home.md", b"new remote head\n")
                    fixture.head = fixture.commit("advance remote")
                    fixture.push()
                else:
                    shutil.rmtree(fixture.remote)
                diagnostics = self.snapshot(fixture, retained, expected_exit=2)
                self.assert_blocked(diagnostics, failure_code)
                catalog_blob = fixture.blob(retained, "ADR-Catalog.json")
                failure = {
                    "code": failure_code,
                    "revision": retained,
                    "path": "ADR-Catalog.json",
                    "expectedBlob": catalog_blob,
                    "observedBlob": catalog_blob,
                    "reliedOn": [self.relied_on(fixture, retained, "ADR-001-Core-Boundary.md")],
                }
                issue, trusted = self.exception_inputs(fixture, retained, [failure])
                result = self.exception(
                    fixture, diagnostics, issue, trusted, expected_exit=0, revision=retained,
                )
                self.assertEqual("proceeding_under_exception", result["status"])
                self.assertIn(failure_code, {item["code"] for item in result["diagnostics"]})

    def test_read_contract_blocks_when_fixed_accepted_objects_are_unavailable(self) -> None:
        fixture = self.fixture(name="missing-fixed-contracts")
        for contract in ("adr-lifecycle", "development-exception"):
            with self.subTest(contract=contract):
                completed, result = self.checker(
                    fixture,
                    "read-contract",
                    "--repository", str(fixture.work),
                    "--contract", contract,
                    expected_exit=2,
                    parse_json=False,
                )
                self.assertIsNone(result)
                self.assertEqual(b"", completed.stdout)
                self.assertNotEqual(b"", completed.stderr)

    def test_read_contract_ignores_local_git_replacement_objects(self) -> None:
        fixture = self.fixture(name="replacement-object")
        fixture.git(
            "update-ref",
            f"refs/replace/{ACCEPTED_CONTRACT_REVISION}",
            fixture.head,
        )
        self.assertEqual(
            b"commit\n",
            fixture.git("cat-file", "-t", ACCEPTED_CONTRACT_REVISION).stdout,
            "fixture must prove the replacement attack is active for ordinary Git reads",
        )
        completed, result = self.checker(
            fixture,
            "read-contract",
            "--repository", str(fixture.work),
            "--contract", "adr-lifecycle",
            expected_exit=2,
            parse_json=False,
        )
        self.assertIsNone(result)
        self.assertEqual(b"", completed.stdout)
        blocked = json.loads(completed.stderr)
        self.assertTrue(any(
            "cannot be read safely" in item["message"]
            for item in blocked["diagnostics"]
        ))

    def test_exception_binding_rejects_wrong_repository_issue_operation_scope_and_content(self) -> None:
        mutations = [
            ("repository", lambda issue, trusted: trusted.update(repository="https://example.invalid/wrong")),
            ("issue", lambda issue, trusted: trusted.update(issue="https://github.com/example/wrong/issues/1")),
            ("operation", lambda issue, trusted: trusted.update(operation="different-operation")),
            ("scope", lambda issue, trusted: trusted.update(blockSha256="0" * 64)),
            ("content", lambda issue, trusted: issue["comments"][0].update(body=issue["comments"][0]["body"].replace("bounded repair", "different terms"))),
        ]
        for index, (name, mutate) in enumerate(mutations):
            with self.subTest(name=name):
                fixture, diagnostics, issue, trusted = self.missing_exception_fixture(f"exception-{index}")
                mutate(issue, trusted)
                result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
                self.assertEqual("blocked", result["status"])

    def test_exception_accepts_realistic_bounded_issue_body_size(self) -> None:
        fixture, diagnostics, issue, trusted = self.missing_exception_fixture("large-issue-body")
        issue["issue"]["body"] = "x" * 10257
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=0)
        self.assertEqual("proceeding_under_exception", result["status"])

    def test_exception_rejects_expired_closed_incomplete_edited_deleted_and_marked_records(self) -> None:
        cases = ["expired", "closed", "incomplete", "edited", "deleted", "revoked", "resolved", "remembered"]
        for index, name in enumerate(cases):
            with self.subTest(name=name):
                fixture, diagnostics, issue, trusted = self.missing_exception_fixture(f"validity-{index}")
                if name == "expired":
                    record = self.read_exception_record(issue)
                    record["expiresAt"] = (
                        datetime.now(timezone.utc) - timedelta(minutes=1)
                    ).strftime("%Y-%m-%dT%H:%M:%SZ")
                    self.bind_exception_record(issue, trusted, record)
                elif name == "closed":
                    issue["issue"]["state"] = "CLOSED"
                elif name == "incomplete":
                    issue["commentsComplete"] = False
                elif name == "edited":
                    issue["comments"][0]["updatedAt"] = "2026-10-02T12:00:01Z"
                elif name == "deleted":
                    issue["comments"] = []
                elif name == "revoked":
                    issue["issue"]["body"] += "\nADR-EXCEPTION-REVOKED: qa-exception-1\n"
                elif name == "resolved":
                    issue["issue"]["body"] += "\nADR-EXCEPTION-RESOLVED: qa-exception-1\n"
                elif name == "remembered":
                    trusted["revokedOrResolvedIds"] = ["qa-exception-1"]
                result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
                self.assertEqual("blocked", result["status"])

    def test_exception_recomputes_diagnostics_and_rejects_changed_current_state(self) -> None:
        fixture, diagnostics, issue, trusted = self.missing_exception_fixture()
        fixture.write("ADR-001-Core-Boundary.md", document_bytes("ADR-001", "Accepted"))
        fixture.head = fixture.commit("repair after diagnostics")
        fixture.push()
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
        self.assertEqual("blocked", result["status"])

    def test_exception_external_json_inputs_must_be_bounded_regular_files(self) -> None:
        fixture, diagnostics, issue, trusted = self.missing_exception_fixture("external-json")
        diagnostics_path = self.write_json("regular-diagnostics.json", diagnostics)
        issue_path = self.write_json("regular-issue.json", issue)
        trusted_target = self.write_json("trusted-target.json", trusted)
        trusted_link = self.temp / "trusted-link.json"
        trusted_link.symlink_to(trusted_target)
        _, linked = self.checker(
            fixture,
            "exception",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--revision", fixture.head,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--diagnostics", str(diagnostics_path),
            "--issue-snapshot", str(issue_path),
            "--trusted-approval", str(trusted_link),
            expected_exit=2,
        )
        self.assertEqual("blocked", linked["status"])

        oversized = self.temp / "oversized-diagnostics.json"
        oversized.write_bytes(b" " * (1024 * 1024 + 1))
        _, large = self.checker(
            fixture,
            "exception",
            "--repository", str(fixture.work),
            "--wiki-repository", CANONICAL_WIKI,
            "--revision", fixture.head,
            "--ticket", TICKET,
            "--operation", OPERATION,
            "--scope", SCOPE,
            "--diagnostics", str(oversized),
            "--issue-snapshot", str(issue_path),
            "--trusted-approval", str(trusted_target),
            expected_exit=2,
        )
        self.assertEqual("blocked", large["status"])

    def test_exception_rejects_ineligible_body_change(self) -> None:
        fixture = self.fixture(name="ineligible")
        path = fixture.work / "ADR-001-Core-Boundary.md"
        path.write_bytes(path.read_bytes().replace(b"Keep the boundary exact.", b"Changed accepted body."))
        fixture.refresh_record_blob("ADR-001")
        fixture.head = fixture.commit("changed accepted body")
        fixture.push()
        diagnostics = self.snapshot(fixture, expected_exit=2)
        self.assert_blocked(diagnostics, "ADR_BODY_CHANGED")
        # Any exact exception record for an ineligible failure must still block.
        issue = {
            "version": 1,
            "issue": {"url": TICKET, "state": "OPEN", "body": "Owning issue."},
            "comments": [],
            "commentsComplete": True,
        }
        trusted = {
            "version": 1,
            "exceptionId": "ineligible",
            "repository": DEVELOPMENT_REPOSITORY,
            "wikiRepository": CANONICAL_WIKI,
            "issue": TICKET,
            "operation": OPERATION,
            "commentId": "none",
            "commentUpdatedAt": "2026-10-02T12:00:00Z",
            "blockSha256": "0" * 64,
            "approvalRef": "trusted-owner-handoff:qa-fixture",
            "revokedOrResolvedIds": [],
        }
        result = self.exception(fixture, diagnostics, issue, trusted, expected_exit=2)
        self.assertEqual("blocked", result["status"])

    def test_cli_misuse_is_64_and_does_not_emit_result_json(self) -> None:
        fixture = self.fixture()
        completed, result = self.checker(fixture, "snapshot", expected_exit=64)
        self.assertIsNone(result)
        self.assertNotEqual(b"", completed.stderr)


if __name__ == "__main__":
    unittest.main()
