#!/usr/bin/env python3
"""Receipt-backed Release Radar release orchestration.

This module is an implementation detail of ``script/build_and_run.sh``.  Both
native delivery and fixture verification execute these same state transitions;
only the bounded operations provider differs.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from typing import Any, NoReturn


SHA_PATTERN = re.compile(r"[0-9a-f]{40}")
DIGEST_PATTERN = re.compile(r"[0-9a-f]{64}")
VERSION_PATTERN = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
BUILD_PATTERN = re.compile(r"[0-9]+")
SUITE_COMMANDS = {"release-radar-tests-v1"}
STAGES = ("preflight", "checks", "stage", "package", "install", "tag", "push_tag")
ACTION_OPERATIONS = {
    "prepare-version",
    "commit-release-metadata",
    "prepare-libgit2",
    "build-stage",
    "verify-bundle",
    "package-dmg",
    "stop-running",
    "copy-bundle",
    "create-tag",
    "push-tag",
}


class ReleaseError(Exception):
    """A bounded release failure safe to persist in the public receipt."""

    def __init__(self, stage: str, code: str, safe_message: str) -> None:
        super().__init__(safe_message)
        self.stage = stage
        self.code = code
        self.safe_message = safe_message


class Context:
    def __init__(
        self,
        repository: Path,
        entrypoint: Path,
        version: str,
        fixture_root: Path | None,
        adapter: Path | None,
    ) -> None:
        self.repository = repository.resolve(strict=True)
        self.entrypoint = entrypoint.resolve(strict=True)
        self.version = version
        self.fixture_root = fixture_root.resolve(strict=True) if fixture_root else None
        self.adapter = adapter.resolve(strict=True) if adapter else None
        if (self.fixture_root is None) != (self.adapter is None):
            raise ValueError("fixture root and operations adapter must be paired")
        if self.fixture_root and not self.adapter.is_relative_to(self.fixture_root):
            raise ValueError("operations adapter must remain under fixture root")

        if self.fixture_root:
            root = self.fixture_root
            downloads = root / "Downloads"
            self.installed_bundle = root / "Applications" / "ReleaseRadar.app"
        else:
            root = self.repository
            downloads = Path.home() / "Downloads"
            self.installed_bundle = Path("/Applications/ReleaseRadar.app")
        self.receipt_path = downloads / f"ReleaseRadar-{version}.release.json"
        self.staged_bundle = root / "dist" / "ReleaseRadar.app"
        self.dmg = root / "dist" / f"ReleaseRadar-{version}.dmg"
        self.installer = downloads / f"ReleaseRadar-{version}.dmg"
        if self.fixture_root:
            for destination in (
                self.receipt_path,
                self.receipt_path.with_suffix(".json.tmp"),
                self.staged_bundle,
                self.dmg,
                self.installer,
                self.installed_bundle,
            ):
                existing = destination
                while not existing.exists() and not existing.is_symlink():
                    existing = existing.parent
                if not existing.resolve().is_relative_to(self.fixture_root):
                    raise ValueError("fixture destination escapes fixture root")

    @property
    def destinations(self) -> dict[str, str]:
        return {
            "staged_bundle": str(self.staged_bundle),
            "dmg": str(self.dmg),
            "installer": str(self.installer),
            "installed_bundle": str(self.installed_bundle),
        }

    def _command(self, operation: str, operands: tuple[str, ...]) -> list[str]:
        if self.adapter:
            return [
                str(self.adapter),
                "--root",
                str(self.fixture_root),
                "--receipt",
                str(self.receipt_path),
                operation,
                *operands,
            ]
        return [
            "bash",
            str(self.entrypoint),
            "release-native-operation",
            "--receipt",
            str(self.receipt_path),
            "--operation",
            operation,
            *operands,
        ]

    def invoke(self, operation: str, *operands: str) -> str:
        completed = subprocess.run(
            self._command(operation, operands),
            cwd=self.repository,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE if self.adapter else None,
            check=False,
        )
        if completed.returncode != 0:
            raise RuntimeError(f"{operation} failed")
        output = completed.stdout
        if operation in ACTION_OPERATIONS:
            if output:
                raise RuntimeError(f"{operation} returned unexpected output")
            return ""
        if not output.endswith("\n") or output.count("\n") != 1:
            raise RuntimeError(f"{operation} returned malformed output")
        return output[:-1]

    def observe_sha(self, operation: str, *operands: str) -> str:
        value = self.invoke(operation, *operands)
        if not SHA_PATTERN.fullmatch(value):
            raise RuntimeError(f"{operation} returned invalid revision")
        return value

    def observe_digest(self, operation: str, *operands: str) -> str:
        value = self.invoke(operation, *operands)
        if not DIGEST_PATTERN.fullmatch(value):
            raise RuntimeError(f"{operation} returned invalid digest")
        return value

    def observe_identity(self, bundle: Path) -> str:
        value = self.invoke("bundle-identity", str(bundle))
        if not value or any(ord(character) < 32 for character in value):
            raise RuntimeError("bundle identity is invalid")
        return value

    def observe_object(
        self, operation: str, operands: tuple[str, ...], required_keys: set[str]
    ) -> dict[str, Any]:
        try:
            value = json.loads(self.invoke(operation, *operands))
        except (json.JSONDecodeError, RuntimeError) as error:
            raise RuntimeError(f"{operation} returned invalid JSON") from error
        if not isinstance(value, dict) or set(value) != required_keys:
            raise RuntimeError(f"{operation} returned an invalid object")
        return value


class Receipt:
    def __init__(self, context: Context, data: dict[str, Any]) -> None:
        self.context = context
        self.data = data
        self.validate()

    @classmethod
    def create(
        cls, context: Context, source_revision: str, build: str, suites: list[str]
    ) -> "Receipt":
        data = {
            "schema_version": 1,
            "candidate": {
                "source_revision": source_revision,
                "version": context.version,
                "build": build,
                "expected_tag": f"v{context.version}",
                "bundle_id": "com.rekonlabs.ReleaseRadar",
                "signing_team": "2UA854NLX4",
                "required_suite_ids": suites,
            },
            "destinations": context.destinations,
            "checks": [],
            "stages": {stage: "pending" for stage in STAGES},
            "artifacts": {
                "staged_bundle_identity": None,
                "dmg_sha256": None,
                "installed_bundle_identity": None,
            },
            "failure": None,
        }
        receipt = cls(context, data)
        receipt.save()
        return receipt

    @classmethod
    def load(cls, context: Context) -> "Receipt":
        try:
            data = json.loads(context.receipt_path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise ValueError("missing or invalid release receipt") from error
        if not isinstance(data, dict):
            raise ValueError("invalid release receipt")
        return cls(context, data)

    @property
    def candidate(self) -> dict[str, Any]:
        return self.data["candidate"]

    def validate(self) -> None:
        required_top = {
            "schema_version",
            "candidate",
            "destinations",
            "checks",
            "stages",
            "artifacts",
            "failure",
        }
        if set(self.data) != required_top or self.data["schema_version"] != 1:
            raise ValueError("unsupported release receipt")
        candidate = self.data["candidate"]
        required_candidate = {
            "source_revision",
            "version",
            "build",
            "expected_tag",
            "bundle_id",
            "signing_team",
            "required_suite_ids",
        }
        if not isinstance(candidate, dict) or set(candidate) != required_candidate:
            raise ValueError("invalid release candidate")
        if (
            not SHA_PATTERN.fullmatch(candidate["source_revision"])
            or candidate["version"] != self.context.version
            or not BUILD_PATTERN.fullmatch(candidate["build"])
            or candidate["expected_tag"] != f"v{self.context.version}"
            or candidate["bundle_id"] != "com.rekonlabs.ReleaseRadar"
            or candidate["signing_team"] != "2UA854NLX4"
            or not isinstance(candidate["required_suite_ids"], list)
            or not candidate["required_suite_ids"]
            or any(suite not in SUITE_COMMANDS for suite in candidate["required_suite_ids"])
        ):
            raise ValueError("release candidate does not match the requested release")
        if self.data["destinations"] != self.context.destinations:
            raise ValueError("release destinations are not canonical")
        if not isinstance(self.data["checks"], list):
            raise ValueError("invalid release checks")
        for check in self.data["checks"]:
            if (
                not isinstance(check, dict)
                or set(check) != {"suite_id", "candidate_sha", "outcome"}
                or check["suite_id"] not in candidate["required_suite_ids"]
                or check["candidate_sha"] != candidate["source_revision"]
                or check["outcome"] not in {"passed", "failed", "skipped", "unavailable"}
            ):
                raise ValueError("invalid release check evidence")
        if set(self.data["stages"]) != set(STAGES) or any(
            disposition not in {"pending", "passed"}
            for disposition in self.data["stages"].values()
        ):
            raise ValueError("invalid release stage disposition")
        if set(self.data["artifacts"]) != {
            "staged_bundle_identity",
            "dmg_sha256",
            "installed_bundle_identity",
        }:
            raise ValueError("invalid release artifact evidence")
        failure = self.data["failure"]
        if failure is not None and (
            not isinstance(failure, dict)
            or set(failure) != {"stage", "code", "safe_message"}
            or failure["stage"] not in STAGES
        ):
            raise ValueError("invalid release failure")

    def save(self) -> None:
        self.validate()
        self.context.receipt_path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            dir=self.context.receipt_path.parent,
            prefix=f".{self.context.receipt_path.name}.",
            suffix=".tmp",
        )
        temporary = Path(temporary_name)
        try:
            with os.fdopen(descriptor, "w") as stream:
                stream.write(json.dumps(self.data, indent=2, sort_keys=True) + "\n")
            temporary.replace(self.context.receipt_path)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise

    def begin_stage(self, stage: str) -> None:
        start = STAGES.index(stage)
        for dependent in STAGES[start:]:
            self.data["stages"][dependent] = "pending"
        if stage == "checks":
            self.data["checks"] = []
        self.data["failure"] = None
        self.save()

    def fail(self, error: ReleaseError) -> NoReturn:
        self.data["failure"] = {
            "stage": error.stage,
            "code": error.code,
            "safe_message": error.safe_message,
        }
        self.save()
        raise error

    def pass_stage(self, stage: str) -> None:
        self.data["stages"][stage] = "passed"
        self.data["failure"] = None
        self.save()

    def require_head(self, context: Context, stage: str) -> None:
        try:
            source_state = context.observe_object("source-state", (), {"clean"})
            current = context.observe_sha("head")
        except RuntimeError:
            self.fail(ReleaseError(stage, "source_revision_unavailable", "release source revision is unavailable"))
        if type(source_state["clean"]) is not bool or not source_state["clean"]:
            self.fail(ReleaseError(stage, "source_checkout_dirty", "release source checkout contains uncommitted changes"))
        if current != self.candidate["source_revision"]:
            self.fail(ReleaseError(stage, "source_revision_mismatch", "release source revision no longer matches HEAD"))

    def require_checks(self, stage: str) -> None:
        if self.data["stages"]["checks"] != "passed":
            self.fail(ReleaseError(stage, "required_checks_missing", "all required checks must pass for this candidate"))
        by_suite = {check["suite_id"]: check for check in self.data["checks"]}
        if any(
            suite not in by_suite or by_suite[suite]["outcome"] != "passed"
            for suite in self.candidate["required_suite_ids"]
        ):
            self.fail(ReleaseError(stage, "required_checks_missing", "all required checks must pass for this candidate"))


def parse_context(arguments: list[str], *, version: str) -> tuple[Context, list[str]]:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--entrypoint", type=Path, required=True)
    known, remaining = parser.parse_known_args(arguments)

    fixture = argparse.ArgumentParser(add_help=False)
    fixture.add_argument("--fixture-root", type=Path)
    fixture.add_argument("--operations-adapter", type=Path)
    fixture_known, remaining = fixture.parse_known_args(remaining)
    return (
        Context(
            known.repository,
            known.entrypoint,
            version,
            fixture_known.fixture_root,
            fixture_known.operations_adapter,
        ),
        remaining,
    )


def ensure_version(value: str) -> str:
    if not VERSION_PATTERN.fullmatch(value):
        raise ValueError("version must use X.Y.Z numeric form")
    return value


def tag_state(context: Context, receipt: Receipt, stage: str) -> str:
    try:
        raw = context.invoke(
            "tag-state",
            receipt.candidate["expected_tag"],
            receipt.candidate["source_revision"],
        )
        value = json.loads(raw)
    except (RuntimeError, json.JSONDecodeError):
        receipt.fail(ReleaseError(stage, "tag_state_invalid", "release tag state is unavailable"))
    if value == {"state": "absent"}:
        return "absent"
    if (
        isinstance(value, dict)
        and set(value) == {"state", "peeled_sha"}
        and value["state"] in {"matching-annotated", "mismatch"}
        and SHA_PATTERN.fullmatch(value["peeled_sha"])
    ):
        if value["state"] == "matching-annotated" and value["peeled_sha"] != receipt.candidate["source_revision"]:
            return "mismatch"
        return value["state"]
    receipt.fail(ReleaseError(stage, "tag_state_invalid", "release tag state is invalid"))


def verify_bundle(context: Context, receipt: Receipt, stage: str, bundle: Path) -> str:
    try:
        context.invoke(
            "verify-bundle",
            str(bundle),
            receipt.candidate["version"],
            receipt.candidate["build"],
        )
        return context.observe_identity(bundle)
    except RuntimeError:
        receipt.fail(ReleaseError(stage, "bundle_invalid", "release bundle verification failed"))


def run_preflight(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "preflight")
    state = tag_state(context, receipt, "preflight")
    if state == "mismatch":
        receipt.fail(ReleaseError("preflight", "tag_collision", "release tag identifies another candidate"))
    try:
        signing = context.observe_object(
            "signing-status",
            (),
            {"available", "team_matches", "authority_matches"},
        )
    except RuntimeError:
        receipt.fail(ReleaseError("preflight", "signing_status_invalid", "signing configuration status is unavailable"))
    if any(type(signing[key]) is not bool for key in signing) or not all(signing.values()):
        receipt.fail(ReleaseError("preflight", "signing_unavailable", "required signing configuration is unavailable"))
    receipt.pass_stage("preflight")


def run_checks(context: Context, receipt: Receipt) -> None:
    if receipt.data["stages"]["preflight"] != "passed":
        receipt.fail(ReleaseError("checks", "preflight_required", "preflight must pass before checks"))
    receipt.require_head(context, "checks")
    try:
        context.invoke("prepare-libgit2")
    except RuntimeError:
        receipt.fail(ReleaseError("checks", "libgit2_unavailable", "the pinned libgit2 dependency could not be prepared"))

    source_revision = receipt.candidate["source_revision"]
    evidence: list[dict[str, str]] = []
    for suite in receipt.candidate["required_suite_ids"]:
        try:
            result = context.observe_object("run-suite", (suite, source_revision), {"outcome"})
        except RuntimeError:
            receipt.fail(ReleaseError("checks", "suite_result_invalid", "required suite result is invalid"))
        outcome = result["outcome"]
        if outcome not in {"passed", "failed", "skipped", "unavailable"}:
            receipt.fail(ReleaseError("checks", "suite_result_invalid", "required suite result is invalid"))
        evidence.append(
            {"suite_id": suite, "candidate_sha": source_revision, "outcome": outcome}
        )
        receipt.data["checks"] = evidence
        receipt.save()
        if outcome != "passed":
            receipt.fail(ReleaseError("checks", "required_suite_not_passed", "a required suite did not pass"))
    receipt.require_head(context, "checks")
    receipt.pass_stage("checks")


def run_stage(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "stage")
    receipt.require_checks("stage")
    recorded = receipt.data["artifacts"]["staged_bundle_identity"]
    if context.staged_bundle.exists() and not recorded:
        receipt.fail(
            ReleaseError(
                "stage",
                "staged_unknown_provenance",
                "existing staged bundle is not bound to this release receipt",
            )
        )
    if context.staged_bundle.exists():
        identity = verify_bundle(context, receipt, "stage", context.staged_bundle)
        if identity != recorded:
            receipt.fail(ReleaseError("stage", "staged_collision", "staged release conflicts with the receipt"))
        receipt.pass_stage("stage")
        return
    try:
        context.invoke(
            "build-stage",
            str(context.staged_bundle),
            receipt.candidate["version"],
            receipt.candidate["build"],
        )
    except RuntimeError:
        receipt.fail(ReleaseError("stage", "build_failed", "release build and staging failed"))
    receipt.require_head(context, "stage")
    identity = verify_bundle(context, receipt, "stage", context.staged_bundle)
    receipt.data["artifacts"]["staged_bundle_identity"] = identity
    receipt.pass_stage("stage")


def run_package(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "package")
    receipt.require_checks("package")
    if receipt.data["stages"]["stage"] != "passed":
        receipt.fail(ReleaseError("package", "stage_required", "staging must pass before packaging"))
    staged_identity = verify_bundle(context, receipt, "package", context.staged_bundle)
    if staged_identity != receipt.data["artifacts"]["staged_bundle_identity"]:
        receipt.fail(ReleaseError("package", "identity_mismatch", "staged bundle identity changed"))

    if context.dmg.exists():
        try:
            digest = context.observe_digest("dmg-sha256", str(context.dmg))
            installer_digest = context.observe_digest(
                "dmg-sha256", str(context.installer)
            )
        except RuntimeError:
            receipt.fail(ReleaseError("package", "checksum_invalid", "release package checksum is invalid"))
        recorded = receipt.data["artifacts"]["dmg_sha256"]
        if not recorded or digest != recorded or installer_digest != digest:
            receipt.fail(ReleaseError("package", "package_collision", "release package conflicts with the receipt"))
        receipt.pass_stage("package")
        return
    if context.installer.exists():
        receipt.fail(ReleaseError("package", "installer_collision", "retained installer already exists"))
    try:
        context.invoke(
            "package-dmg",
            str(context.staged_bundle),
            str(context.dmg),
            str(context.installer),
            receipt.candidate["version"],
            receipt.candidate["build"],
            staged_identity,
        )
        digest = context.observe_digest("dmg-sha256", str(context.dmg))
        installer_digest = context.observe_digest(
            "dmg-sha256", str(context.installer)
        )
    except RuntimeError:
        receipt.fail(ReleaseError("package", "package_failed", "release package creation or verification failed"))
    if installer_digest != digest:
        receipt.fail(ReleaseError("package", "installer_mismatch", "retained installer differs from the verified package"))
    receipt.data["artifacts"]["dmg_sha256"] = digest
    receipt.pass_stage("package")


def run_install(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "install")
    receipt.require_checks("install")
    if receipt.data["stages"]["package"] != "passed":
        receipt.fail(ReleaseError("install", "package_required", "packaging must pass before installation"))
    staged_identity = verify_bundle(context, receipt, "install", context.staged_bundle)
    if staged_identity != receipt.data["artifacts"]["staged_bundle_identity"]:
        receipt.fail(ReleaseError("install", "identity_mismatch", "staged bundle identity changed"))

    recorded_installed = receipt.data["artifacts"]["installed_bundle_identity"]
    if recorded_installed and context.installed_bundle.exists():
        installed_identity = verify_bundle(context, receipt, "install", context.installed_bundle)
        if installed_identity != recorded_installed or installed_identity != staged_identity:
            receipt.fail(ReleaseError("install", "installed_identity_mismatch", "installed bundle conflicts with the receipt"))
        receipt.pass_stage("install")
        return
    if not recorded_installed and context.installed_bundle.exists():
        try:
            context.invoke(
                "verify-bundle",
                str(context.installed_bundle),
                receipt.candidate["version"],
                receipt.candidate["build"],
            )
            installed_identity = context.observe_identity(context.installed_bundle)
        except RuntimeError:
            installed_identity = None
        if installed_identity == staged_identity:
            receipt.data["artifacts"]["installed_bundle_identity"] = installed_identity
            receipt.pass_stage("install")
            return

    if context.installed_bundle.exists():
        try:
            context.invoke(
                "verify-bundle",
                str(context.installed_bundle),
                receipt.candidate["version"],
                receipt.candidate["build"],
                "prior-destination",
            )
        except RuntimeError:
            receipt.fail(ReleaseError("install", "installed_destination_invalid", "installed destination is not a compatible verified release"))

    try:
        context.invoke("stop-running")
        context.invoke(
            "copy-bundle",
            str(context.staged_bundle),
            str(context.installed_bundle),
            receipt.candidate["version"],
            receipt.candidate["build"],
            staged_identity,
        )
    except RuntimeError:
        receipt.fail(ReleaseError("install", "install_failed", "verified release installation failed"))
    installed_identity = verify_bundle(context, receipt, "install", context.installed_bundle)
    if installed_identity != staged_identity:
        receipt.fail(ReleaseError("install", "installed_identity_mismatch", "installed bundle differs from the staged candidate"))
    receipt.data["artifacts"]["installed_bundle_identity"] = installed_identity
    receipt.pass_stage("install")


def run_tag(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "tag")
    receipt.require_checks("tag")
    if receipt.data["stages"]["install"] != "passed":
        receipt.fail(ReleaseError("tag", "install_required", "installation must pass before tagging"))
    state = tag_state(context, receipt, "tag")
    if state == "matching-annotated":
        receipt.pass_stage("tag")
        return
    if state != "absent":
        receipt.fail(ReleaseError("tag", "tag_collision", "release tag identifies another candidate"))
    try:
        context.invoke(
            "create-tag",
            receipt.candidate["expected_tag"],
            receipt.candidate["source_revision"],
        )
    except RuntimeError:
        receipt.fail(ReleaseError("tag", "tag_create_failed", "release tag creation failed"))
    if tag_state(context, receipt, "tag") != "matching-annotated":
        receipt.fail(ReleaseError("tag", "tag_verification_failed", "created release tag does not identify the candidate"))
    receipt.pass_stage("tag")


def run_push_tag(context: Context, receipt: Receipt) -> None:
    receipt.require_head(context, "push_tag")
    receipt.require_checks("push_tag")
    if receipt.data["stages"]["tag"] != "passed":
        receipt.fail(ReleaseError("push_tag", "tag_required", "local tag must pass before publication"))
    if tag_state(context, receipt, "push_tag") != "matching-annotated":
        receipt.fail(ReleaseError("push_tag", "tag_mismatch", "local release tag does not match the candidate"))
    try:
        context.invoke("push-tag", receipt.candidate["expected_tag"])
        remote = context.observe_sha(
            "remote-peeled-sha", receipt.candidate["expected_tag"]
        )
    except RuntimeError:
        receipt.fail(ReleaseError("push_tag", "tag_push_failed", "release tag publication or verification failed"))
    if remote != receipt.candidate["source_revision"]:
        receipt.fail(ReleaseError("push_tag", "remote_tag_mismatch", "published release tag identifies another candidate"))
    receipt.pass_stage("push_tag")


STAGE_RUNNERS = {
    "preflight": run_preflight,
    "checks": run_checks,
    "stage": run_stage,
    "package": run_package,
    "install": run_install,
    "tag": run_tag,
    "push_tag": run_push_tag,
}


def initialize(context: Context, build: str, suites: list[str]) -> None:
    if not BUILD_PATTERN.fullmatch(build):
        raise ValueError("build must be numeric")
    if not suites or len(suites) != len(set(suites)) or any(
        suite not in SUITE_COMMANDS for suite in suites
    ):
        raise ValueError("required suites must be unique supported suite identifiers")
    if context.receipt_path.exists() or context.dmg.exists() or context.installer.exists():
        raise ValueError("release receipt or package destination already exists")
    if not context.fixture_root:
        status = subprocess.run(
            ["git", "-C", str(context.repository), "status", "--porcelain"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if status.returncode != 0 or status.stdout:
            raise ValueError("release-init requires a clean checkout")
    initial_revision = context.observe_sha("head")
    try:
        initial_tag_state = json.loads(
            context.invoke("tag-state", f"v{context.version}", initial_revision)
        )
    except (json.JSONDecodeError, RuntimeError) as error:
        raise ValueError("release tag state is unavailable") from error
    if initial_tag_state != {"state": "absent"}:
        raise ValueError("release tag already exists")
    context.invoke("prepare-version", context.version, build)
    context.invoke("commit-release-metadata", context.version)
    source_revision = context.observe_sha("head")
    Receipt.create(context, source_revision, build, suites)


def main(argv: list[str]) -> int:
    global_parser = argparse.ArgumentParser(add_help=False)
    global_parser.add_argument("--repository", type=Path, required=True)
    global_parser.add_argument("--entrypoint", type=Path, required=True)
    global_args, remaining = global_parser.parse_known_args(argv)
    if not remaining:
        raise ValueError("release command is required")
    command, command_arguments = remaining[0], remaining[1:]

    parser = argparse.ArgumentParser(prog=f"build_and_run.sh {command}")
    parser.add_argument("--version", type=ensure_version, required=True)
    parser.add_argument("--fixture-root", type=Path)
    parser.add_argument("--operations-adapter", type=Path)
    if command == "release-init":
        parser.add_argument("--build", required=True)
        parser.add_argument("--required-suite", action="append", default=[])
    elif command == "release-delivery":
        parser.add_argument("--stage", choices=STAGES, required=True)
    else:
        raise ValueError("unsupported release command")
    arguments = parser.parse_args(command_arguments)
    context = Context(
        global_args.repository,
        global_args.entrypoint,
        arguments.version,
        arguments.fixture_root,
        arguments.operations_adapter,
    )

    if command == "release-init":
        initialize(context, arguments.build, arguments.required_suite)
        return 0

    receipt = Receipt.load(context)
    receipt.begin_stage(arguments.stage)
    STAGE_RUNNERS[arguments.stage](context, receipt)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except ReleaseError as error:
        print(f"error: {error.safe_message}", file=sys.stderr)
        raise SystemExit(1)
    except (KeyError, OSError, RuntimeError, TypeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
