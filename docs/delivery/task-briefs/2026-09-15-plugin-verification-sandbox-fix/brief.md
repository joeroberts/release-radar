# Signed helper plugin verification regression — completed

Restore installed-package verification under the shipped helper's signed sandbox
without expanding its filesystem access. The reported 0.1.17 helper repeatedly
returns `integrityUnknown` for the recognized installed four-file package. The
home-directory read open is a hypothesis until an isolated signed probe supplies
the syscall result and immediate errno; no production fix precedes that evidence.

Scope is the production helper reader, meaningful boundary regression and unsafe
synthetic tests, the owning mutable lifecycle design, and necessary catalog/index
and existing ledger coherence. Preserve descriptor-relative no-follow traversal,
the effective-user home, the exact fixed cache/version root, retained entry/handle
identity and stability checks, compatible inventories and frozen digests, and
existing caller error/status mapping. No general harness, refactor, broad home
entitlement, sandbox disabling, permission or configuration change is authorized.

The baseline is `328f27372ea0904f7eaedc97a983b96ce0e05523` on existing branch
`codex/plugin-verification-sandbox-fix`, rooted at
`/Users/jroberts/.codex/worktrees/118f/release_radar`. PR #69 is merged and this
baseline includes 0.1.17 packaging; there is no stacked dependency. Writer task
`01a0a72d-ad56-7b52-b034-de468f0d38c9` owns source/tests/docs and scoped local
commits. Sol/high is assigned, ceiling Astra/high only for a reported named
problem; the task API does not expose actual model/effort readback.

Main coordinates all test execution with BuildAgent
`01a0a51a-43e5-7a62-8571-519dfc7e57d7`, the exclusive owner of native compilation,
signing, execution, and `.build/signed-sandbox-probe/` scratch in this worktree.
The isolated probe compiles the production reader with a tiny temporary entry
point, uses the same parsed helper entitlements, Hardened Runtime and development
signing identity with a distinct probe identifier, and records effective-home
lookup, metadata, home open/errno, allowed `.codex` open/errno and the last reader
event/error. It reads no configuration or unrelated plugin content and writes no
owner plugin state. Any alternate descriptor-open contrast is coordinated by Main.

Risks are loss of legitimate sandbox access, symlink escape, entry replacement or
restoration, unstable reads and changes to digest or recovery semantics. Begin
with signed reproduction and a failing legitimate-boundary regression, then make
the smallest supported reader correction and run focused native tests of the
actual production reader. Cover both recognized inventories, home and fixed-root
symlinks, replacement races and unchanged digest framing. A signed post-fix probe
must verify the previously failing boundary without changing live helper state.
Repository documentation validation and `git diff --check` establish document
coherence and patch hygiene; they do not establish runtime correctness.

Acceptance requires concrete signed reproduction, a minimal fix preserving the
security boundary, passing direct regression/unsafe tests and signed recheck, and
one independent code/security review assigned by Main through RO04. The reviewer
receives the original outcome, exact candidate and direct evidence. Required
corrections remain in scope; optional findings do not block.

[ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) retains the
accepted lifecycle boundary. The [mutable lifecycle design](../../../design/release-radar-codex-plugin-lifecycle-design.md)
owns implementation details. Existing status/install/reinstall postconditions
consume the unchanged reader contract. No public interface, persistence migration
or new recovery protocol is required; existing versioned installers remain rollback
copies. Accepted ADRs and governing instructions remain unchanged.

Endpoint is source/tests/docs, direct checks, scoped local commit and independent
review, then BuildAgent's separately assigned 0.1.18 version/package/DMG commit,
authorized normal push/PR and annotated version tag. Installation is on hold.
No main merge, notarization, registration, restart, reinstall, app launch,
installation, owner plugin writes, application/catalog acceptance or SQLite
mutation is authorized here. Preserve the existing 0.1.17 package and tag.

Shared Execution V1 and tracking installed skill reads were denied by the effective
restricted profile. Repository-local authority, material independent review,
explicit acceptance/external-effect boundaries and safety/recovery fallbacks apply;
packaged source skills supply diagnostic context only, not installed compatibility
proof. The catalog remains pending application acceptance after repository edits.
The brief and catalog/index/ledger changes are durable repository artifacts; the
BuildAgent probe and native runner outputs are temporary build scratch.

## Direct verification

Main/BuildAgent's isolated signed baseline probe used the actual production
reader and the installed/source helper's matching parsed entitlements, Hardened
Runtime and development signing identity. Effective-home lookup and home metadata
succeeded; the read-only home open failed with immediate `EPERM`, direct `.codex`
open succeeded, and the reader returned `integrityUnknown`. An event-only home
open also failed. The signed search-only contrast opened home, successfully
validated its descriptor metadata and opened `.codex` with descriptor-relative
read-only flags. This confirms the requested minimal anchor correction without
an entitlement change.

Before the production correction, the actual unchanged reader and twelve native
XCTest methods executed: eleven passed and the legitimate traversal-only-home
regression failed with `integrityUnknown`, runner exit 1. Home replacement races
and all ten prior unsafe/compatibility methods passed. An initial runner launch
failed on an XCTest dependency and supplied no test evidence; the documented
framework environment resolved it. Main reported a serialized repository
documentation check passed after edits stabilized.

The corrected actual reader and unchanged twelve-test candidate then executed
with twelve passes, zero failures and zero unexpected exceptions. The frozen
legacy/current digest regression and home/fixed-root symlink and replacement
checks passed. BuildAgent's copied reader and test sources match this working
tree byte-for-byte. The corrected signed production-reader probe retained the
same sandbox entitlements and Hardened Runtime, reached the home and `.codex`
descriptor anchors, read exactly the four recognized package files and completed
snapshot validation. Its 0.1.17 digest matched Main's previously verified
`94d7c1c3c506e3b62f7710e7e84df8ad4fc671b9029d06b1f0369b2882230a07`.
The old read-only home diagnostic still returned `EPERM` in that same process.
These isolated checks preserve live helper/app/plugin state; they do not verify
an installed 0.1.18 helper or the deferred real reinstall journey. Final
documentation validation passed. Independent RO04 reviewer
`01a0a73a-7c0a-7573-9d8c-4722b79b19fa` passed source candidate
`a30cfea04944e84559c208b4961dca1e57079c9e` with no findings.

## Authorized 0.1.18 delivery assignment

Main transferred sole branch/source/docs/release ownership to the standing BuildAgent
at reviewed `a30cfea04944e84559c208b4961dca1e57079c9e`. The owner authorized
0.1.18 (1) metadata, a signed Release build, the versioned repository and Downloads
DMG, existing tracked staged app, independent package/version review, normal PR
and annotated v0.1.18 tag publication. The source security review is complete;
package review does not reopen it. Preserve all 0.1.17 installers/tags and prior
recognized digests. Installation remains on hold; no live helper restart,
registration/reinstall, app launch, owner plugin writes, notarization, GitHub
Release, main merge or application catalog acceptance is authorized.

Use the existing staging/signing workflow. Directly compare source and signed
payload version/digest/registry, exact entitlements, source/staged/mounted payload
and DMG checksums. Retain the signed real-home O_SEARCH proof and exercise the
unchanged reader on isolated 0.1.18 payload content under the same entitlements.
The twelve containment tests remain terminal unless their inputs or reader change;
app-hosted version XCTest is excluded by the no-launch boundary. Commit clean
build-source metadata before building and identify the separate reviewed artifact
commit before tagging. Record results in the existing ledger and
[0.1.18 evidence](../../evidence/2026-09-15-release-0.1.18-packaging.md).

Package direct checks passed: fresh Release staging, exact signatures/entitlements,
production Core version/digest/capability, signed isolated 0.1.18 reader, APFS image,
read-only mounted payload and matching Downloads copy. Independent package/version review passed exact artifact `4ebbf754` with no
findings; branch/normal [PR #70](https://github.com/joeroberts/release-radar/pull/70)
and annotated `v0.1.18` on that artifact are published. Live installed-helper replacement remains excluded.

This brief is completed and non-authoritative. The existing progress ledger owns
current coordination and installation hold; no further action is authorized by
historical implementation assignments above.
