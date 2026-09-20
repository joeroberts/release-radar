# Release Radar documentation

## Current reading routes

Start here, then follow only the route needed for the task. Catalog lifecycle is
about document use; it does not approve product work or change delivery state.

| Need | Read in order |
| --- | --- |
| Current authorization, active outcome, or next work | [Delivery state](delivery/progress.md), then its linked active brief |
| Existing product behavior or a product change | [Product design index](design/README.md), the owning active design, and only the accepted ADRs it cites |
| Managed-document change, lifecycle change, or rename | [Managed repository documentation contract](design/managed-repository-documentation-contract.md), [ADR-006](architecture/ADR-006-managed-repository-documentation-contract.md), then the current delivery state |
| Shared Execution V1 compatibility or adoption diagnosis | [Shared Execution Integration V1](design/shared-execution-integration-v1-design.md), then the consumer's own instructions and delivery state. V1 source delivery does not prove installation, runtime loading, or adoption. |
| Proposed whole-product or companion work | [Full-product plan](delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md) and the linked proposed design. Read each section's approval qualification; proposal inclusion is not implementation authority. |

Completed assignments, evidence, and archive records are not default specification
inputs. When a named historical fact is needed, locate the exact stable artifact ID
or path in [the catalog](catalog.json), confirm its lifecycle and authority, and
follow the local [task-brief](delivery/task-briefs/README.md),
[evidence](delivery/README.md), or [archive](delivery/archive/README.md) index. Use
that record as attributed provenance only; return to the current route above for
present requirements and authorization.

## Native developer setup

This records the owner-confirmed host setup reported by Main on September 15,
2026. It does not grant configuration or release authority. The catalog has no
separate active developer/build guide; this existing entry point owns the
reusable setup, while the [release evidence](delivery/evidence/2026-09-15-release-0.1.17-packaging.md)
records verification and the [ledger](delivery/progress.md) records current state.

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

- [architecture](architecture) — leaf; Accepted architecture and delivery-policy decisions
- [brand](brand/README.md) — indexed; Approved V1 brand direction and retained design references
- [delivery](delivery/README.md) — indexed; Current delivery status and durable task/evidence history
- [design](design/README.md) — indexed; Accepted product contracts and clearly classified proposals

## Leaf collection: architecture

- Path: [docs/architecture](architecture)
- Purpose: Accepted architecture and delivery-policy decisions
- Allowed contents: Architecture decision records
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [fd278d0d-b43f-4145-9033-2906f32a6ab8](architecture/ADR-001-release-radar-boundaries.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| fd278d0d-b43f-4145-9033-2906f32a6ab8 | [docs/architecture/ADR-001-release-radar-boundaries.md](architecture/ADR-001-release-radar-boundaries.md) | document | controlling &#40;architecture.boundaries&#41; | active | none | none |
| de35fa8c-3615-4b7f-a028-100aaadaeaf8 | [docs/architecture/ADR-002-codex-plugin-lifecycle.md](architecture/ADR-002-codex-plugin-lifecycle.md) | document | controlling &#40;architecture.codex-plugin-lifecycle&#41; | active | none | none |
| f7cd9af5-0cd1-4707-b05e-007222e0ca8a | [docs/architecture/ADR-003-active-phase-selection.md](architecture/ADR-003-active-phase-selection.md) | document | controlling &#40;architecture.active-phase-selection&#41; | active | none | none |
| 6369c974-23ac-467b-90b7-0c0d0ad426fd | [docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md](architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md) | document | controlling &#40;architecture.delivery-goals-readiness&#41; | active | none | none |
| 9c1cf54c-99cf-4348-af72-1aedc07deb02 | [docs/architecture/ADR-005-ticket-task-work-plans.md](architecture/ADR-005-ticket-task-work-plans.md) | document | controlling &#40;architecture.ticket-tasks&#41; | active | none | none |
| 874c6a9a-f7e9-444e-b38d-c32ceb18a536 | [docs/architecture/ADR-006-managed-repository-documentation-contract.md](architecture/ADR-006-managed-repository-documentation-contract.md) | document | controlling &#40;architecture.managed-documentation&#41; | active | none | none |
| a3918ee6-cc82-40f2-ae84-2d59571b2020 | [docs/architecture/ADR-007-proportional-delivery-validation.md](architecture/ADR-007-proportional-delivery-validation.md) | document | controlling &#40;delivery.validation-policy&#41; | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
