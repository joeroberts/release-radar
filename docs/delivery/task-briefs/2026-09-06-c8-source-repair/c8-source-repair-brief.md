# C8 source-repair pilot

Date: 2026-09-06. Status: local source delivery complete and independently reviewed;
installed acceptance remains outstanding. Retained as active supporting installation
handoff material; current authorization and status are in the progress ledger.

## Objective and outcome

Deliver the independently reviewed exact `.DS_Store` discovery repair, affected
versioned contract and shipped reference, focused regression evidence, scoped
local commits and a concrete installation handoff. This source checkpoint does
not complete the broader C8 freshness feature or installed acceptance.

The owner submitted the [kickoff](../2026-09-06-operating-baseline/c8-pilot-kickoff.md)
in the new orchestrator task. The handoff baseline is
`69d62b00de429eadc55041bbedc34c26b749b09f` on
`codex/full-product-architecture-plan`, following approved operating baseline
`44dc75b1cf63837e22e5cf18773178576d55c618`. The architect's committed compatibility
section must be available in the delivery worker baseline before implementation.

## Scope and exclusions

Exclude only exact `.DS_Store` ordinary regular files from managed-document
discovery, after obtaining file type without following symlinks. Apply the same
rule at the immediately affected index-write stability boundary. Root and nested
metadata must leave document inventory and catalog digest unchanged across reads.
Preserve existing conservative concurrent-change detection and all real-document
checks. Reject same-named directories/symlinks and catalog entries, other prohibited
paths, unregistered documents, unsafe roots and evidence use of excluded metadata.

Update only the shared reader/contract, affected existing tests, managed-documentation
design, shipped catalog reference and directly affected documentation. Do not
change `.gitignore`, delete metadata, introduce blanket hidden-file exclusions,
implement freshness/lifecycle/recovery/hooks work, or add dependencies/frameworks.
No SQLite writes, owner data/state mutation, binding/catalog acceptance, audit
reconstruction, installation, launch, push, PR, merge, publication or rule changes.

## Dependencies and future consumers

Use [ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), the
[managed-documentation contract](../../../design/managed-repository-documentation-contract.md)
and the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Accepted identity, custody and explicit acceptance rules remain controlling; the
plan's other proposed decisions are not approved by this pilot.

Current consumers are the app catalog reader, generated indexes, bundled checker,
catalog acceptance and managed evidence resolution. Future consumers include C8
freshness, C9 evidence, C12 health/recovery, C10/C11 portability, P15/P16 traceability
and revisions, and P17 revision/build evidence. Metadata is never an artifact or
accepted evidence. Preserve repository/artifact IDs, catalog format and digest
meaning; no persistence migration or implicit acceptance follows this rule. Old
installed validators remain restrictive until an explicitly authorized upgrade.
The architect's C8 compatibility section selects
`RepositoryDocumentContract.discoveryExclusionVersion = 1`; schema v1, guidance v2
and catalog digest encoding remain unchanged.

## Assignment and ownership

- Orchestrator: Astra Medium, sole progress/catalog/index writer in the existing
  handoff worktree; coordinates commits and task archival, no product code or subagents.
- Chief architect: Astra High, isolated worktree, owns the C8 compatibility section
  in the existing managed-documentation design and scoped local commit. Bounded
  whole-product alignment; not an extra approval layer.
- Delivery owner: Terra Medium, fresh isolated worktree from the committed brief
  and architecture result; owns C8 implementation, existing tests, affected design/
  shipped reference, required corrections, local source commits and integration.
  Do not write progress/catalog/index metadata; report requested changes to the
  orchestrator. A source staging build is permitted; installed/owner state is not.
- Independent reviewer: fresh Sol High task on the candidate, with original outcome
  and future dependencies. Cover reader correctness, contract and filesystem safety
  together; no writer ownership, extra reviewers, worker goals or review chains.

The default escalation ceiling is Astra High for a named unresolved problem.
Extra High/Max require specific owner authorization; Ultra is prohibited. Actual
model/effort settings are set at dispatch. Delivery subagents are optional only
for concrete justified work with explicit settings and disjoint ownership.

## Risks, checks and acceptance

Material risks are bypassing filesystem safety, accepting excluded metadata as an
artifact, divergent app/checker rules, index-write failure, and falsely claiming
installed acceptance. Use test-first changes in existing repository suites:
`RepositoryDocumentCatalogTests`, `RepositoryDocumentIndexTests` and directly
relevant documentation-tool/evidence tests. Select only additional suites justified
by an affected boundary; no new harness or full product test campaign.

Required regressions cover docs-root and nested regular metadata; creation,
modification and removal between reads with equal inventory/digest; same-named
symlinks and directories; explicitly catalogued metadata; ordinary unregistered
files; existing prohibited paths and containment; and index check/write agreement.
Keep index stability conservative for unsafe entries and real-document changes.
Build the app and bundled checker from the same candidate and exercise existing
repository-native checks, including the original canonical metadata failure using
read-only validation. Never use the owner store as a fixture.

Source acceptance requires direct passing checks, affected documentation consistency,
one independent review with no unresolved Required findings, scoped local commits,
repository-persisted results, stopped child processes and prompt archival of
completed bounded tasks. Classify findings Required, Optional or Out of scope;
only Required defects block and repeat only affected checks/review.

## Delivery endpoint and installation handoff

Delivery returns the exact candidate revision, changed behavior/docs, test commands
and results, staged candidate location or reproducible staging command, and exact
remaining installation action. Keep useful results in this brief and the existing
progress ledger. Build/log/worktree scratch is temporary; durable content must be
tracked and present in the repository before completion. List remaining temporary
files; obtain authorization before deletion.

The orchestrator goal ends at the reviewed local source checkpoint and concrete
installation handoff. Record installed acceptance as outstanding: owner-authorized
replacement of the exact installed app, installed reader/bundled-checker agreement
on the actual repository with metadata present, and supported application readback.
Missing binding/pending catalog acceptance or reset recovery remains separately
reported work, never an implicit side effect of installation or this goal.

## Source candidate and installation handoff

Source candidate commit: `35e2ef60347e366ab43f8131ab5d99a99af6a6d8`
(`Fix Finder metadata discovery`). It adds
`RepositoryDocumentContract.discoveryExclusionVersion = 1` without changing
catalog schema v1, guidance v2, or digest encoding; regular exact `.DS_Store`
entries are excluded only after no-follow type inspection, while catalog
registration and non-regular lookalikes still reject. The index writer uses the
same type-checked rule for its staging stability comparison.

Direct verification on that commit: the focused reader/index/reference suites
passed 46 tests (`RepositoryDocumentCatalogTests`, `RepositoryDocumentIndexTests`,
and the C8 reference test), run with:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-c8-green -only-testing:ReleaseRadarTests/RepositoryDocumentCatalogTests -only-testing:ReleaseRadarTests/RepositoryDocumentIndexTests -only-testing:ReleaseRadarTests/ManagedGuidanceCompatibilityTests/testDiscoveryExclusionVersionAndShippedReferenceAgree
```

A standalone source helper and the bundled helper in the staged app both ran
`check` and `write` successfully against disposable copies of this repository's
`docs/` tree containing regular root and nested `.DS_Store` files; the write
reported zero generated-index changes. No owner repository, SQLite store,
installed app, binding, catalog acceptance, or launch was used.

The reviewed, unlaunched Release candidate is
`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar-C8-source-35e2ef6.app`
(version `0.1.6`, build `1`, bundle ID `com.rekonlabs.ReleaseRadar`, Team ID
`2UA854NLX4`, Apple Development signing identity `Apple Development:
jaroberts4@gmail.com (PT7GS96H3L)`). Its main binary SHA-256 is
`06931783b7717060baaaff682d8b5ebd32ddc3424e72c70e5f460984a864a28e`. The
pre-existing `dist/ReleaseRadar.app` was not changed.

The owner approved the following reviewed preparation and no-launch installation
sequence, which Codex executed on 2026-09-06. This is the retained installation record,
not an instruction to repeat the sequence. The integrated handoff
worktree has the reviewed source and candidate. The approved
fail-fast sequence preserved the pre-existing default staged bundle before
placing the C8 candidate at the native installer's expected path:

```sh
set -euo pipefail
candidate="/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar-C8-source-35e2ef6.app"
handoff_root="/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/build/product-architecture-plan-worktree"
default_stage="$handoff_root/dist/ReleaseRadar.app"
prior_stage="$handoff_root/dist/ReleaseRadar.pre-C8-source-35e2ef6.app"
test -d "$candidate"
test -e "$default_stage"
test ! -e "$prior_stage"
mv "$default_stage" "$prior_stage"
ditto "$candidate" "$default_stage"
"$handoff_root/script/build_and_run.sh" install-staged-release-no-launch
```

This sequence was not executed at the source checkpoint; it was executed after
the owner subsequently approved the exact no-launch installation. The native installer,
rather than `ditto` directly into `/Applications`, owns process shutdown,
signature and identity verification, atomic promotion, backup and rollback.
The prior staged bundle remains recoverably at
`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/build/product-architecture-plan-worktree/dist/ReleaseRadar.pre-C8-source-35e2ef6.app`;
the sequence never removes it.
Installed acceptance remains the separately authorized check of the installed
reader and bundled checker against the actual repository with metadata retained,
followed by supported application readback; missing binding and pending catalog
acceptance remain separate recovery work.

### Artifact disposition and retained verification

The canonical durable candidate for owner review is
`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar-C8-source-35e2ef6.app`.
The parent separately performed a read-only canonical staged-helper check with
the actual retained `.DS_Store` metadata and reported it passed. That parent
verification is distinct from this delivery task's disposable-fixture checks and
does not establish installation or application acceptance.

The worktree-local copy at
`/Users/jroberts/.codex/worktrees/6130/release_radar/dist/ReleaseRadar-C8-source-35e2ef6.app`,
`/Users/jroberts/.codex/worktrees/6130/release_radar/DerivedData`,
`/tmp/release-radar-c8-red`, `/tmp/release-radar-c8-green`, and
`/tmp/release-radar-c8-helper-build` are temporary build/test output. The
remaining temporary fixture roots are
`/private/tmp/release-radar-c8-helper.tURlit`,
`/private/tmp/release-radar-c8-helper-plain.RyL1Ew`,
`/private/tmp/release-radar-c8-helper-green.yAw8ws`,
`/private/tmp/release-radar-c8-helper-green.ZiH8qN`, and
`/private/tmp/release-radar-c8-staged-check.YIq4nP`. No cleanup is authorized
or performed by this task.

### Approved no-launch installation result — 2026-09-06

The native installer completed successfully at `/Applications/ReleaseRadar.app`.
Installed version 0.1.6 build 1 and main-binary SHA-256 match the approved candidate
recorded above. Native signature, identity and promotion checks passed. The installed
`Contents/Helpers/ReleaseRadarDocumentationTool check --root` against the canonical
repository passed with actual `.DS_Store` retained. The GUI was not launched, and
an exact process check found the installed app executable was not running.

The prior staged bundle named above remains preserved. No discretionary cleanup
of the listed temporary outputs occurred; the native installer's own temporary
promotion/backup cleanup ran as part of the approved procedure. Launch-based app-
reader acceptance and supported application readback remain separately authorized
work. No binding, catalog acceptance, audit reconstruction or recovery was performed.
