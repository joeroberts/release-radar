# Release Radar 0.1.17 local release

Main authorized this release on September 15, 2026 under the standing local
release workflow. Current state remains in [progress](../../progress.md).

Current assignment: the owner explicitly authorized the designated BuildAgent to
build and verify 0.1.17, persist the DMG in Git and Downloads, and publish its
branch through a normal PR plus an annotated version tag after independent
package review. **Installation remains on hold.** App launch, notarization,
GitHub Release creation, main merge and application-state mutations are excluded.

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

Single release writer: the standing BuildAgent task, branch
`codex/release-0.1.17-package`, root
`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/build/release-0.1.17-package-worktree`,
committed baseline `b8a21539383dedbce9d6b6f9844849f7568203d5`.
The current task's model/effort setting is not exposed to the delivery worker;
no model escalation is requested. Main dispatches the independent RO04 package
review. Use the existing Xcode staging workflow with command-local Git isolation,
temporary/compiler caches and default SwiftPM sandboxing. Preserve canonical-main
state, governing files, existing installers and historical tags.

## Risks, checks and acceptance

Risks are version/digest drift, installer collision, nested signing or entitlement
drift, package identity mismatch and replacing active installed processes. Use
the established `script/build_and_run.sh stage-release-no-launch` workflow;
verify all nested code, Hardened Runtime and approved entitlements. Run focused
non-launch version/digest/capability checks and the repository documentation check.
The existing version XCTest uses the app as TEST_HOST; it is not run under the
no-app-launch boundary. Report this limitation and the actual test count. Build
an APFS DMG containing `ReleaseRadar.app` and an `Applications` link, verify its
payload, SHA-256 and matching Downloads copy, and preserve exact source provenance.
Main arranges one fresh independent review of exact package identity, signing,
source/version provenance, DMG contents and delivery documentation before publication.
Do not
claim notarization, general-distribution trust, app acceptance or owner-data
verification. No persistence migration or public contract change is intended.
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md) and
[ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) retain their
architecture/security boundaries; existing lifecycle consumers remain compatible.

## Delivery endpoint

Scoped release commit containing verified `dist/ReleaseRadar-0.1.17.dmg` and
accurate delivery records; matching `/Users/jroberts/Downloads/ReleaseRadar-0.1.17.dmg`;
new annotated `v0.1.17` tag on the release commit; branch and tag pushed after
independent review; normal PR against `main`. Never move an existing tag or
overwrite an installer. Installation, app launch, main merge, GitHub Release,
notarization, database access, binding, catalog acceptance and configuration
changes remain excluded. Repository/package checks do not establish application
synchronization. No version bump beyond the existing 0.1.17 (1) is authorized.
