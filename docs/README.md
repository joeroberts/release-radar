# Release Radar documentation

## Product knowledge and delivery

The [Product Specifications](https://github.com/joeroberts/release-radar/wiki/Product-Specifications)
and accepted entries in [Architecture Decisions](https://github.com/joeroberts/release-radar/wiki/Architecture-Decisions)
own product behavior and architectural decisions. Repository routing stubs
preserve stable local links. `docs/delivery/plans/` owns implementation
sequences, dependencies, and rollout gates. Pending ADR-005 and ADR-006 remain
repository-canonical with their existing approval qualifications.

## Current reading routes

Start here, then follow only the route needed for the task. Catalog lifecycle is
about document use; it does not approve product work or change delivery state.

| Need | Read in order |
| --- | --- |
| Authorization and development rules | The owner's current instructions, then [repository agent instructions](../AGENTS.md). Documents and issue status do not grant additional authorization. |
| Current work, acceptance criteria, status, or results | The relevant [GitHub issue](https://github.com/joeroberts/release-radar/issues). Confirm its current state before acting. |
| Initialize a development task | The [RR Development Delegation Model](https://github.com/joeroberts/release-radar/wiki/RR-Development-Delegation-Model), its appropriate role prompt, and the ticket-specific assignment. Consult the [GitHub Issue Standard](https://github.com/joeroberts/release-radar/wiki/GitHub-Issue-Standard) only when creating an issue. |
| Resume the current development task | The relevant GitHub work and current owner instructions, then the [current handoff](delivery/progress.md) for additional context. The handoff is a navigation aid, not an authorization source. |
| Existing product behavior or a product change | [Product Specifications](https://github.com/joeroberts/release-radar/wiki/Product-Specifications), the ticket-relevant specification, and only the accepted decisions it cites |
| RR product behavior for managed documents, lifecycle changes, or renames | [Managed repository documentation specification](https://github.com/joeroberts/release-radar/wiki/Spec-Managed-Repository-Documentation) and repository-canonical [ADR-006](architecture/ADR-006-managed-repository-documentation-contract.md). These define RR product behavior, not the process for developing RR. |
| Shared Execution V1 compatibility or adoption diagnosis | [Shared Execution V1](https://github.com/joeroberts/release-radar/wiki/Spec-Shared-Execution-V1), then the consumer's own instructions and delivery state. V1 source delivery does not prove installation, runtime loading, or adoption. |
| Proposed whole-product or companion work | [Full-product plan](delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md) and the linked proposed design. Read each section's approval qualification; proposal inclusion is not implementation authority. |

Product specifications and accepted decisions each have one canonical Wiki
location. The former repository authoring paths are non-authoritative routing
stubs. ADR-005 and ADR-006 remain repository-canonical pending their recorded
owner acceptance. Preserve accepted ADR decision text.

Current specifications own continuing product requirements. Completed delivery
paperwork is removed rather than retained in a competing archive. Git preserves
historical versions; GitHub issues hold current work and useful results.

## Native developer setup

This records the owner-confirmed host setup reported by Main on September 15,
2026. It does not grant configuration or release authority. The catalog has no
separate active developer/build guide; this existing entry point owns the
reusable setup; the [ledger](delivery/progress.md) records current state.

The confirmed `rr-project-restricted` filesystem profile keeps root denial and
minimal read access, with read access to `/Applications/Xcode.app`,
`/Library/Developer`, `/System/Library` and `/opt/homebrew`; write access to
`:tmpdir`, the assigned worktree and `~/Library/Caches/org.swift.swiftpm`.
Existing narrow Git, credential and workspace permissions remain in force.
No opaque system Clang-cache write grant is part of this setup.

When updating the Codex TOML setup, replace the existing table rather than
appending another table with the same name. Main removed only the second
identical `:workspace_roots` table after the duplicate prevented task delivery;
full parser/readback validation passed and permissions were unchanged by that
deduplication. Start a fresh task turn after configuration changes and verify
effective access before retrying a previously denied operation.

Main's fresh readback confirmed zero `SWIFTPM_MODULECACHE_OVERRIDE` entries in
the owner's `.zshrc`. Keep this setting per build/worktree. An interactive shell
startup export using `$PWD` captures the directory at export time and does not
follow later `cd` commands; it is unsuitable for automation. Do not source the
owner's startup file to prepare a build. Owner-reported cache-directory creation
has not been independently verified; retain any existing cache pending scoped
cleanup.

For an authorized native build, first enter the intended worktree and create its
cache. `env` below exports absolute paths for that build's child processes:

```sh
cd /absolute/path/to/release_radar-worktree &&
mkdir -p "$PWD/.build/swiftpm-module-cache" "$PWD/.build/tmp" &&
env \
  PATH=/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin \
  TMPDIR="$PWD/.build/tmp" \
  SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swiftpm-module-cache" \
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_OPTIONAL_LOCKS=0 \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper \
  GIT_CONFIG_VALUE_0='!/opt/homebrew/Cellar/gh/2.96.0/bin/gh auth git-credential' \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination platform=macOS -derivedDataPath "$PWD/DerivedData" \
  SWIFT_MODULE_CACHE_PATH="$PWD/.build/swiftpm-module-cache" \
  CLANG_MODULE_CACHE_PATH="$PWD/.build/swiftpm-module-cache" build
```

Use the authorized focused test filters and a fresh result path for test runs;
local release staging uses the existing `script/build_and_run.sh` workflow with
the same explicit environment. The `gh` path above is the verified local
installation and uses its existing login without persistent Git configuration.
Verify tool paths on another host.

`SWIFTPM_MODULECACHE_OVERRIDE` is an unadvertised compatibility hook implemented
by the [Swift 6.3.3 manifest loader](https://raw.githubusercontent.com/swiftlang/swift-package-manager/swift-6.3.3-RELEASE/Sources/PackageLoading/ManifestLoader.swift).
Its task-local Swift module-file creation was verified here; this does not
guarantee future toolchain compatibility or a green native build. App build
settings alone did not redirect the manifest compiler cache, and the public
`-packageCachePath` attempt did not relocate its `.dia` output. Recheck behavior
after toolchain updates. Installation timing follows the current delivery ledger.

## Development documentation checks

Run the repository validator against the working tree with:

```sh
swift script/check_development_docs.swift --root "$(git rev-parse --show-toplevel)"
```

The checked-in pre-commit hook validates the staged
`docs/delivery/progress.md` snapshot, including when that file was not changed
in the current commit. To opt in locally, run
`script/install_development_docs_hook.sh --install`; use `--status` to report
whether this repository's resolved hook location contains the checked-in hook.
Installation refuses to overwrite an existing hook and does not change
`core.hooksPath`.

Local hooks can be bypassed with Git's `--no-verify` option. The checked-in
hook, local installation, GitHub workflow, and any repository required-check
setting are separate states. The workflow validates pull requests and pushes to
`main` with read-only repository permission; enabling it as a required check
remains a separate repository-settings decision.

<!-- release-radar-docs:v1:start -->

## Collection: docs

- Path: [docs](.)
- Purpose: Release Radar documentation, current authority, and retained history
- Allowed contents: Architecture, design, brand, and delivery collections; Catalog and navigation indexes
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [c48466fb-a4fd-4f9e-96bf-967dfa173216](README.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| c48466fb-a4fd-4f9e-96bf-967dfa173216 | [docs/README.md](README.md) | collectionIndex | supporting | active | none | none |

### Children

- [architecture](architecture) — leaf; Repository routing stubs for accepted Wiki decisions and repository-canonical pending decisions
- [brand](brand/README.md) — indexed; Approved V1 brand direction and retained design references
- [delivery](delivery/README.md) — indexed; Current delivery status and durable task/evidence history
- [design](design/README.md) — indexed; Repository routing stubs for canonical Wiki product specifications and repository-owned visual references

## Leaf collection: architecture

- Path: [docs/architecture](architecture)
- Purpose: Repository routing stubs for accepted Wiki decisions and repository-canonical pending decisions
- Allowed contents: Pending or proposed repository-canonical architecture records; Wiki routing stubs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [fd278d0d-b43f-4145-9033-2906f32a6ab8](architecture/ADR-001-release-radar-boundaries.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| fd278d0d-b43f-4145-9033-2906f32a6ab8 | [docs/architecture/ADR-001-release-radar-boundaries.md](architecture/ADR-001-release-radar-boundaries.md) | document | supporting | active | none | none |
| de35fa8c-3615-4b7f-a028-100aaadaeaf8 | [docs/architecture/ADR-002-codex-plugin-lifecycle.md](architecture/ADR-002-codex-plugin-lifecycle.md) | document | supporting | active | none | none |
| f7cd9af5-0cd1-4707-b05e-007222e0ca8a | [docs/architecture/ADR-003-active-phase-selection.md](architecture/ADR-003-active-phase-selection.md) | document | supporting | active | none | none |
| 6369c974-23ac-467b-90b7-0c0d0ad426fd | [docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md](architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md) | document | supporting | active | none | none |
| 9c1cf54c-99cf-4348-af72-1aedc07deb02 | [docs/architecture/ADR-005-ticket-task-work-plans.md](architecture/ADR-005-ticket-task-work-plans.md) | document | controlling &#40;architecture.ticket-tasks&#41; | active | none | none |
| 874c6a9a-f7e9-444e-b38d-c32ceb18a536 | [docs/architecture/ADR-006-managed-repository-documentation-contract.md](architecture/ADR-006-managed-repository-documentation-contract.md) | document | controlling &#40;architecture.managed-documentation&#41; | active | none | none |
| a3918ee6-cc82-40f2-ae84-2d59571b2020 | [docs/architecture/ADR-007-proportional-delivery-validation.md](architecture/ADR-007-proportional-delivery-validation.md) | document | supporting | active | none | none |
| rr-adr-008-opt-in-project-execution | [docs/architecture/ADR-008-opt-in-project-execution.md](architecture/ADR-008-opt-in-project-execution.md) | document | supporting | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
