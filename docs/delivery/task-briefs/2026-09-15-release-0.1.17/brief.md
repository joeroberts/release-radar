# Release Radar 0.1.17 local release

Main authorized this release on September 15, 2026 under the standing local
release workflow. Current state remains in [progress](../../progress.md).

Current assignment is documentation-only: record the owner-confirmed native
setup in [the existing developer entry point](../../../README.md#native-developer-setup),
correct this brief/evidence/ledger, run documentation checks and make a scoped
local documentation commit. Main arranges correction review through release
reviewer `01a0a48a`. No native builds, configuration/startup-file edits or build
logic changes are released by this assignment. **Installation is on hold** on
the owner's later instruction; prior standing delivery language below does not
clear that hold.

## Objective, scope and dependencies

Package the independently reviewed installed-cache containment fix merged in
[PR #65](https://github.com/joeroberts/release-radar/pull/65), baseline
`89dfc85ad330a30a2ae48d09c7e5252a44ac5111`, as `0.1.17 (1)`. Own only consistent
app/plugin version metadata, the new exact recognized package digest and focused
version expectations, this brief, package evidence, catalog/indexes and the
existing progress ledger. Preserve historical version/digest pairs, entitlements,
helper/XPC contracts and release tags. Outcome 3 runtime enforcement is separate
and remains unopened. No product implementation or rerun of passed containment
tests is required absent a concrete behavior change.

## Assignment and boundaries

Single release writer: Sol/high, branch `codex/cache-containment-patch-release`,
root `/Users/jroberts/.codex/worktrees/d7aa/release_radar`, exact baseline above.
Main owns independent-review dispatch; installation requires an explicit owner
resume after the hold and the required independent review.
Escalation ceiling remains the assigned profile; request only concrete runtime
permission gates. Use direct Xcode Git with command-local disabled global/system
configuration and optional locks, and worktree-local command-scoped temporary
and compiler caches. Preserve canonical-main state, unrelated work, preservation
references and existing installers. Old `63ab` residue inspection is read-only.

## Risks, checks and acceptance

Risks are version/digest drift, installer collision, nested signing or entitlement
drift, package identity mismatch and replacing active installed processes. Use
the established `script/build_and_run.sh stage-release-no-launch` workflow;
verify all nested code, Hardened Runtime and approved entitlements. Run focused
existing version/capability checks and the repository documentation check. Build
an APFS DMG containing `ReleaseRadar.app` and an `Applications` link, verify its
payload, SHA-256 and matching Downloads copy, and preserve exact source provenance.
Main arranges one fresh read-only metadata/package review before installation.
After Main releases installation, use the existing non-launch install operation
and verify installed version, signature and matching staged identity. Do not
claim notarization, general-distribution trust, app acceptance or owner-data
verification. No persistence migration or public contract change is intended.
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md) and
[ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) retain their
architecture/security boundaries; existing lifecycle consumers remain compatible.

## Delivery endpoint

Scoped local release commit, consistent patch metadata, new annotated local
`v0.1.17` tag on that release commit, verified signed
`dist/ReleaseRadar-0.1.17.dmg`, matching
`/Users/jroberts/Downloads/ReleaseRadar-0.1.17.dmg`, and verified installation at
`/Applications/ReleaseRadar.app` after independent review. Never move an existing
tag or overwrite an existing installer. No push, tag push, PR, merge, public
release, notarization, app launch, database access, binding, catalog acceptance,
configuration or owner-data mutation. Catalog changes remain pending application
acceptance; repository and package checks do not establish synchronization.
