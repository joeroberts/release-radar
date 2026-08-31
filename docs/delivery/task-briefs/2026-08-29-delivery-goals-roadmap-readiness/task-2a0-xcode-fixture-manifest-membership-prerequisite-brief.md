# RR-R10 Task 2A0 Brief: Xcode Fixture-Manifest Membership Prerequisite

**Status:** Post-GREEN plan correction required. The owner-authorized project
edit and both builds are complete; RED and GREEN must not be rerun. Independent
postimplementation review remains closed until this revised registered brief
and coordinator ledger are committed as the exact correction checkpoint,
pushed, remote-exact, and released by Architecture, TPM, QA/Test, Delivery
Management, and Security/Privacy with GO and Required 0.

## Size assessment and checkpoint decision

This prerequisite is one minimal Xcode project-membership correction with one
direct build failure and one direct build success as its test cycle. It is
substantially below the owner's roughly-eight-hour split threshold and has one
coherent review surface, so no further split is warranted.

This prerequisite does not replace or amend Task 2A. Task 2A remains paused
with its already-generated schema-v11 fixture and checksum untracked and
byte-identical until this prerequisite and its post-GREEN correction are
independently accepted, committed, pushed, and remote-exact.

## Objective and owner-visible outcome

Remove the Xcode test-bundle resource collision between the existing
`Fixtures/SchemaV10/SHA256SUMS` and the newly generated
`Fixtures/SchemaV11/SHA256SUMS` by excluding only the SchemaV11 manifest from
automatic `ReleaseRadarTests` target membership.

There is no application-visible change. The owner-visible value is a repaired,
deterministic build boundary that lets Task 2A resume its mandated regression
without altering either fixture, its source-relative test access, or any
accepted product behavior.

## Owner authorization and blocker determination

On 2026-08-30, after Task 2A GREEN generated its two authorized SchemaV11
artifacts, the mandated fresh regression build failed because Xcode flattened
both source manifests to one test-bundle resource destination named
`SHA256SUMS`. The owner explicitly approved this exact bounded prerequisite:
add only `Fixtures/SchemaV11/SHA256SUMS` to the existing
`ReleaseRadarTests` `PBXFileSystemSynchronizedBuildFileExceptionSet`
`membershipExceptions` list.

The coordinator-supplied blocker determination is narrow:

- the two inputs are
  `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS` and
  `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`;
- the single colliding output is the hosted test bundle's
  `ReleaseRadarTests.xctest/Contents/Resources/SHA256SUMS`;
- the generated SchemaV11 database and manifest are not the cause and must not
  be regenerated, rewritten, staged, or committed in this prerequisite;
- the Task 2A generator RED is already immutable evidence and must never be
  rerun; and
- the smallest correction is test-target membership metadata, not source,
  fixture, schema, entitlement, sandbox, or build-setting work.

Independent reviewers revalidated that classification against the `fccab15…`
brief and project source before RED. A different root cause would have been
Required and stopped implementation rather than expanding this prerequisite.

## Confirmed post-GREEN correction context

The initial planning checkpoint is
`fccab15dacef8ad4452743a7e75ebf8773304cf3`. The fresh Implementer completed
the authorized one-entry project edit and retained exact RED/GREEN evidence.
Independent root verification confirmed the project and fixture boundary, the
collision oracle, both build statuses, restricted-log hashes and modes, the
SchemaV10 bundle comparison, the exact RED failure marker, and the final-nonempty
GREEN success marker. The Implementer's corrected temporary report is
`DONE_WITH_CONCERNS` because its first report incorrectly claimed the literal
generic success marker passed.

The defect is in this brief's RED marker oracle, not in the authorized
project edit or build result. Xcode `build-for-testing` emitted
`** TEST BUILD FAILED **` for RED and `** TEST BUILD SUCCEEDED **` for GREEN.
No new build, project edit, fixture change, source/test change, or recovery
mutation is authorized. The only executable continuation is the correction
checkpoint and retained-evidence gate in Step 7, followed by independent
postimplementation review.

## Controlling references and immutable hashes

- Owner-accepted Ticket Tasks design:
  `docs/design/release-radar-ticket-tasks-design.md`, accepted SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`
- Owner-accepted ADR:
  `docs/architecture/ADR-005-ticket-task-work-plans.md`, accepted SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`
- Owner-accepted implementation plan:
  `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  accepted SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`
- Final accepted Task 2A brief:
  `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`,
  registered SHA-256
  `9b3601afe91045479ded8ca38371ee254685d512fb5759a38f452d447949806a`
- `docs/delivery/progress.md`, especially the accepted Task 1A/1B boundaries,
  Task 2A planning and immutable RED history, corrected pre-GREEN gate, and
  current dependency state
- `ReleaseRadar.xcodeproj/project.pbxproj`, especially exception set
  `A90000000000000000000003` for target
  `A20000000000000000000004 /* ReleaseRadarTests */`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`, especially
  `copyVerifiedVersionTenFixture()`, whose `#filePath`-relative source lookup is
  intentionally independent of test-bundle resource membership

This prerequisite cites the accepted plan and Task 2A brief as immutable
context. It does not edit either artifact, reinterpret their fixture contract,
or change their registered hashes.

The accepted Phase Board mockup is downstream context only. This prerequisite
changes no UI and authorizes no visual deviation.

## Dependencies and release gate

- Branch must be exactly `codex/release-radar-mvp`.
- The corrected Task 2A pre-GREEN checkpoint is commit
  `d8bda5a035e0324acd90bcbe67036f8d217b18bf`, present locally and on
  `origin/codex/release-radar-mvp` with exact equality and upstream
  ahead/behind `0/0` before this planning work.
- The initial Task 2A0 planning checkpoint is
  `fccab15dacef8ad4452743a7e75ebf8773304cf3`, a direct child of
  `d8bda5a035e0324acd90bcbe67036f8d217b18bf`, with exactly the brief, root
  registry, and coordinator ledger in its commit inventory. Step 0 is the
  historical pre-RED gate that passed there; it is not rerun post-execution.
- The accepted design, ADR, plan, and Task 2A brief hashes above must remain
  exact.
- The accepted Task 1A SchemaV10 artifacts remain immutable. The database is
  278,528 bytes at SHA-256
  `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`;
  its `SHA256SUMS` is 91 bytes at SHA-256
  `c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f`.
- The two untracked SchemaV11 artifacts generated by Task 2A GREEN are the
  exact preserved implementation inputs. The database is 348,160 bytes at
  SHA-256
  `ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c`;
  its one-line `SHA256SUMS` is 91 bytes at SHA-256
  `ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3`.
- This correction revises this canonical brief and its exactly one
  root-registry entry.
  Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy
  already returned GO with Required 0 on the `fccab15…` brief before RED; those
  dispositions remain historical evidence and do not authorize a rerun. The
  same independent roles must disposition this revised correction before the
  implementation checkpoint.
- The coordinator records owner authorization, exact brief SHA, registry
  verification, role dispositions, and checkpoint evidence in
  `docs/delivery/progress.md`.
- The initial planning checkpoint is complete at `fccab15…`; it must not be
  amended or replaced. The correction checkpoint must be its single direct
  child and contain exactly this revised brief, the root brief registry, and
  coordinator-owned `docs/delivery/progress.md`. It must be committed, pushed,
  and verified at exact local/upstream/live-remote equality with ahead/behind
  `0/0` before Step 7 and independent postimplementation review.
- The Implementer already completed its sole authorized
  `ReleaseRadar.xcodeproj/project.pbxproj` edit. No writer may modify that
  project file, either fixture directory, retained log/build evidence, or any
  source/test file during correction.
- After the correction checkpoint and Step 7 pass, a fresh independent Code
  Reviewer and QA/Test verifier, plus Architecture, Security/Privacy, TPM, and
  Delivery Management, must each return GO with Required 0 before commit.
- The implementation checkpoint may contain only
  `ReleaseRadar.xcodeproj/project.pbxproj` and coordinator-owned
  `docs/delivery/progress.md`. It must be committed, pushed, and verified at
  exact local/remote equality with ahead/behind `0/0` before Task 2A resumes.

## In scope

- Preserve the historical pre-RED checks and verify all controlling hashes and
  fixture byte identities against the completed RED/GREEN state.
- Accept the one already-completed absent-DerivedData
  `xcodebuild build-for-testing` RED only from its exact retained hashes,
  status `65`, marker-scan status `1`, one collision, two producers, exactly
  one exact `** TEST BUILD FAILED **` marker, and zero success markers.
- Disable signing only on both build commands with the identical invocation
  arguments `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`; do not edit a
  build setting.
- Preserve the completed edit that adds exactly one membership exception,
  `Fixtures/SchemaV11/SHA256SUMS`, to exception set
  `A90000000000000000000003` for `ReleaseRadarTests`.
- Preserve the existing SchemaV10 test-bundle membership and every unrelated
  exception byte-semantically.
- Parse the modified project through Xcode and prove the exact authorized diff.
- Enforce a global tracked boundary: before RED there is no tracked or staged
  diff; after the edit and through post-GREEN review the sole tracked worktree
  diff is `ReleaseRadar.xcodeproj/project.pbxproj`, the index is empty, and the
  sole untracked status item is the preserved SchemaV11 directory.
- Prove the shared scheme and every repository-owned `.entitlements` file are
  byte-identical to the planning checkpoint before RED, after the edit, and
  after GREEN.
- Accept the already-completed argument-identical absent-DerivedData GREEN only
  from its exact retained hash, status `0`, marker-scan status `1`, exactly one
  terminal `** TEST BUILD SUCCEEDED **`, zero
  `** TEST BUILD FAILED **`, zero collision diagnostics, and exact SchemaV10
  bundled-manifest comparison.
- Commit and remotely verify one correction-only checkpoint, then run only the
  read-only Step 7 correction-authority/retained-evidence gate. Do not execute
  either build again.
- Prove the SchemaV10 manifest remains in the built test bundle while the
  SchemaV11 manifest is excluded only from target membership.
- Prove both SchemaV10 and SchemaV11 fixture pairs remain regular non-symlink
  source-tree files, canonically contained under their expected directories,
  checksum-valid, and available through the source-relative path used by
  `#filePath`-based tests.
- Record review, build, hash, diff, and Git evidence in the coordinator-owned
  progress ledger.

## Out of scope

- Any edit to the accepted Task 2A brief, accepted implementation plan,
  accepted design, ADR, RED evidence packet, or their hashes
- Any edit, regeneration, replacement, staging, or commit of either SchemaV11
  artifact
- Any edit to SchemaV10 artifacts
- Any edit to product source, test source, schemes, test plans, build settings,
  entitlements, signing, sandbox, resources outside the one membership entry,
  or any other project object
- Any project-file build-setting change for signing; signing is disabled only
  by identical ephemeral RED/GREEN command-line arguments
- Renaming either manifest, changing a fixture directory layout, adding a copy
  phase, preserving both manifests in the test bundle under renamed outputs,
  or adding a generalized resource-packaging mechanism
- Rerunning Task 2A's immutable missing-gate generator RED, its export, its
  GREEN generator, or generating another SchemaV11 attachment
- Rerunning this prerequisite's already-completed RED or GREEN, creating new
  DerivedData, replacing retained evidence, or deleting retained evidence
  without owner authorization
- Running Task 2A's post-generation regression before this prerequisite GREEN
  and independent acceptance
- Schema v12, Task 2B, Ticket Task models/policy/commands/UI, Delivery Goal
  work, or any later RR-R10 task
- Launching or installing the owner-facing app, accessing the owner's SQLite
  store, using owner UI, calling bridge/MCP tools, creating a live Ticket Tasks
  plan, changing RR-R10, changing an Accepted ticket, sending a notification,
  or mutating any external state
- Implementer edits to `docs/delivery/progress.md`; only the coordinator owns
  ledger updates

## Affected subsystem and anticipated files

Initial planning checkpoint (complete at `fccab15…`):

- Create:
  `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md`
- Modify: `docs/delivery/task-briefs/SHA256SUMS`
- Coordinator modify: `docs/delivery/progress.md`

Implementation checkpoint:

- Modify: `ReleaseRadar.xcodeproj/project.pbxproj`
- Coordinator modify: `docs/delivery/progress.md`

Correction checkpoint:

- Modify:
  `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md`
- Modify: `docs/delivery/task-briefs/SHA256SUMS`
- Coordinator modify: `docs/delivery/progress.md`

The correction checkpoint does not contain `project.pbxproj`; that completed
authorized edit remains an unstaged worktree diff for Step 7 and the later
implementation checkpoint.

Consumed unchanged:

- `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`
- `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
- all accepted design, architecture, plan, Task 2A, and RED-evidence artifacts

Temporary build/log files must remain under one unique mode-`700` `/tmp`
parent for each RED or GREEN invocation and are not durable deliverables. Raw
and normalized logs are mode-`600` regular non-symlinks. Keep the restricted
temporary log directories through all independent postimplementation reviews,
disclose their exact paths as temporary evidence, and do not delete them
without owner authorization.

## Data, persistence, security, and privacy implications

- No SQLite database is opened by application code in this prerequisite. The
  fixture checks use only repository test artifacts and `shasum`; the build
  compiles the isolated test target without running tests.
- The owner database, app container, bookmarks, credentials, Keychain, project
  content, and installed application are never accessed.
- Both fixture directories and all four files are checked with no-follow type
  tests before any read. Canonical paths must remain beneath the repository's
  `ReleaseRadarTests/Fixtures` directory.
- The project exception changes only automatic membership of the SchemaV11
  manifest in the built test bundle. It does not remove the source file,
  change its bytes, or prevent tests from loading it relative to the compiled
  source location exposed by `#filePath`.
- The existing SchemaV10 manifest remains a test-bundle resource. The GREEN
  bundle check must prove it is the sole `Contents/Resources/SHA256SUMS` and is
  byte-identical to the SchemaV10 source manifest.
- No permission, entitlement, signing identity, sandbox capability, network
  access, bridge authority, or SQLite authority changes. RED and GREEN disable
  signing only with identical `xcodebuild` command-line arguments and make no
  persistent build-setting change.
- Raw build logs necessarily contain the owner-authorized canonical repository
  path because the accepted collision diagnostic names both exact manifest
  inputs. They must contain no owner database bytes or content, credentials,
  tokens, passwords, authorization headers, or private-key material. A narrow
  fail-closed marker scan checks both RED logs and the GREEN log. Only quiet
  `rg` status `1` (no match) passes; status `0` (marker found) and every status
  greater than `1` (scanner, I/O, or regex failure) reject without printing
  matching content.
- Raw and normalized logs are restricted temporary evidence only: never stage,
  commit, transmit, or copy them into a durable artifact. Only sanitized
  diagnostic facts, commands, modes, temporary paths, and hashes enter
  `docs/delivery/progress.md`; no raw log content does. Retain the restricted
  temporary directories through independent postimplementation review,
  disclose their paths as temporary, and do not delete them without explicit
  owner authorization.

## Exact implementation contract

In the existing object
`A90000000000000000000003 /* Exceptions for ReleaseRadarTests folder in ReleaseRadarTests target */`,
change only its `membershipExceptions` value by adding this one relative path:

```text
Fixtures/SchemaV11/SHA256SUMS
```

The entry belongs in the existing exception set whose target is
`A20000000000000000000004 /* ReleaseRadarTests */`. Do not create a new
exception set, group, file reference, build file, resources phase, target, or
build setting.

`Fixtures/SchemaV10/SHA256SUMS` must not be added to the exception set. All
eight existing CodexPluginLifecycle exception paths must remain present and
unchanged. Every other byte in the project file must match the planning
checkpoint's project blob.

## Test fixtures and test-first strategy

Use only repository-native Git, shell tools, Xcode, `plutil`, `rg`, `realpath`,
`stat`, `cmp`, and `shasum`. Add no test source, dependency, script, fixture,
or harness.

### Step 0: Historical pre-RED planning-authority and tracked-boundary gate

This `/bin/bash` block records the gate conditions and pinned values satisfied
from the canonical repository root immediately before Step 1 and RED at the
initial planning checkpoint. It is retained as historical evidence and must
not be rerun after execution:

```bash
set -euo pipefail
export LC_ALL=C
RR_TASK2A0_ROOT="$(git rev-parse --show-toplevel)"
RR_TASK2A0_BRANCH=codex/release-radar-mvp
RR_TASK2A0_PARENT=d8bda5a035e0324acd90bcbe67036f8d217b18bf
RR_TASK2A0_PLANNING_SHA=fccab15dacef8ad4452743a7e75ebf8773304cf3
RR_TASK2A0_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md
RR_TASK2A0_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A0_LEDGER=docs/delivery/progress.md
RR_TASK2A0_PROJECT=ReleaseRadar.xcodeproj/project.pbxproj
RR_TASK2A0_SCHEME=ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme

test "$(pwd -P)" = "$(realpath "$RR_TASK2A0_ROOT")"
test "$(git branch --show-current)" = "$RR_TASK2A0_BRANCH"
test -f "$RR_TASK2A0_BRIEF"
test ! -L "$RR_TASK2A0_BRIEF"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_BRIEF")" = "Regular File"

# A literal digest inside the file being digested would create a hash paradox.
# Pin the final brief non-self-referentially: its computed digest must equal its
# sole exact registry entry, the full registry must verify, and that registered
# pair must be the one committed and live-remote-exact checkpoint below.
RR_TASK2A0_BRIEF_DIGEST="$(shasum -a 256 "$RR_TASK2A0_BRIEF" | awk '{print $1}')"
test "$(awk -v brief="$RR_TASK2A0_BRIEF" '$2 == brief { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A0_REGISTRY")" = "1"
RR_TASK2A0_REGISTERED_DIGEST="$(awk -v brief="$RR_TASK2A0_BRIEF" \
  '$2 == brief { print $1 }' "$RR_TASK2A0_REGISTRY")"
test "$RR_TASK2A0_REGISTERED_DIGEST" = "$RR_TASK2A0_BRIEF_DIGEST"
RR_TASK2A0_EXPECTED_REGISTRY_ENTRY="$RR_TASK2A0_BRIEF_DIGEST  $RR_TASK2A0_BRIEF"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_REGISTRY_ENTRY" \
  "$RR_TASK2A0_REGISTRY")" = "1"
shasum -a 256 -c "$RR_TASK2A0_REGISTRY"

test "$(git log -1 --format=%H -- "$RR_TASK2A0_BRIEF")" = \
  "$RR_TASK2A0_PLANNING_SHA"
test "$(git rev-parse HEAD)" = "$RR_TASK2A0_PLANNING_SHA"
test "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA^")" = "$RR_TASK2A0_PARENT"
RR_TASK2A0_EXPECTED_INVENTORY="$(printf '%s\n' \
  "$RR_TASK2A0_BRIEF" \
  "$RR_TASK2A0_REGISTRY" \
  "$RR_TASK2A0_LEDGER" | sort)"
RR_TASK2A0_ACTUAL_INVENTORY="$(git diff-tree --no-commit-id --name-only -r \
  "$RR_TASK2A0_PLANNING_SHA" | sort)"
test "$RR_TASK2A0_ACTUAL_INVENTORY" = "$RR_TASK2A0_EXPECTED_INVENTORY"

for checkpoint_file in \
  "$RR_TASK2A0_BRIEF" \
  "$RR_TASK2A0_REGISTRY" \
  "$RR_TASK2A0_LEDGER" \
  "$RR_TASK2A0_PROJECT"; do
  test "$(git hash-object "$checkpoint_file")" = \
    "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$checkpoint_file")"
  cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$checkpoint_file") \
    "$checkpoint_file"
done

git diff --exit-code
git diff --cached --exit-code
test "$(git status --short --untracked-files=normal)" = \
  "?? ReleaseRadarTests/Fixtures/SchemaV11/"
test "$(git status --short --untracked-files=all)" = \
  "$(printf '?? %s\n?? %s' \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"

test "$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = \
  "origin/$RR_TASK2A0_BRANCH"
test "$(git rev-parse '@{upstream}')" = "$RR_TASK2A0_PLANNING_SHA"
RR_TASK2A0_REMOTE_LINES="$(git ls-remote --heads origin \
  "refs/heads/$RR_TASK2A0_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2A0_REMOTE_LINES" | awk 'NF { count += 1 } END { print count + 0 }')" = "1"
test "$(printf '%s\n' "$RR_TASK2A0_REMOTE_LINES" | awk '{print $1}')" = \
  "$RR_TASK2A0_PLANNING_SHA"
read -r RR_TASK2A0_AHEAD RR_TASK2A0_BEHIND < <(
  git rev-list --left-right --count HEAD...'@{upstream}'
)
test "$RR_TASK2A0_AHEAD" = "0"
test "$RR_TASK2A0_BEHIND" = "0"

test "$(git hash-object "$RR_TASK2A0_SCHEME")" = \
  "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME")"
cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME") \
  "$RR_TASK2A0_SCHEME"
RR_TASK2A0_CURRENT_ENTITLEMENTS="$(git ls-files '*.entitlements' | sort)"
RR_TASK2A0_CHECKPOINT_ENTITLEMENTS="$(git ls-tree -r --name-only \
  "$RR_TASK2A0_PLANNING_SHA" | awk '/[.]entitlements$/ { print }' | sort)"
test -n "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
test "$RR_TASK2A0_CURRENT_ENTITLEMENTS" = \
  "$RR_TASK2A0_CHECKPOINT_ENTITLEMENTS"
while IFS= read -r entitlement_file; do
  test "$(git hash-object "$entitlement_file")" = \
    "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$entitlement_file")"
  cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$entitlement_file") \
    "$entitlement_file"
done <<< "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
git diff --exit-code "$RR_TASK2A0_PLANNING_SHA" -- \
  "$RR_TASK2A0_SCHEME" \
  '*.entitlements'
```

Historical result: the recorded conditions were satisfied at
`fccab15dacef8ad4452743a7e75ebf8773304cf3`. This gate tied the then-computed
brief digest `7bcc795213f385ff8ba6290234fca296553932cd5793706d721c9be6c824d774`
to its sole full-registry-verified entry, the exact three-path planning commit,
its `d8bda5…` parent, clean pre-RED state, and exact upstream/live remote. The
non-self-referential digest check avoided a hash paradox. Step 0 is immutable
historical evidence; use Step 7 after the correction checkpoint and do not
rerun Step 0, RED, or GREEN.

### Step 1: Historical pre-RED immutable and no-follow boundary

The Implementer ran this `/bin/bash` block from the canonical repository root
before editing the project. Step 7 rechecks the retained fixture boundary; do
not rerun Step 1 as a route to another RED:

```bash
set -euo pipefail
RR_TASK2A0_ROOT="$(git rev-parse --show-toplevel)"
test "$(pwd -P)" = "$(realpath "$RR_TASK2A0_ROOT")"
test "$(git branch --show-current)" = "codex/release-radar-mvp"

test "$(shasum -a 256 docs/design/release-radar-ticket-tasks-design.md | awk '{print $1}')" = \
  "c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08"
test "$(shasum -a 256 docs/architecture/ADR-005-ticket-task-work-plans.md | awk '{print $1}')" = \
  "6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5"
test "$(shasum -a 256 docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md | awk '{print $1}')" = \
  "2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1"
test "$(shasum -a 256 docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md | awk '{print $1}')" = \
  "9b3601afe91045479ded8ca38371ee254685d512fb5759a38f452d447949806a"

rr_task2a0_require_directory() {
  test -d "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Directory"
}
rr_task2a0_require_file() {
  test -f "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Regular File"
}
RR_TASK2A0_FIXTURE_PARENT="$RR_TASK2A0_ROOT/ReleaseRadarTests/Fixtures"
rr_task2a0_require_directory "$RR_TASK2A0_FIXTURE_PARENT"
test "$(realpath "$RR_TASK2A0_FIXTURE_PARENT")" = \
  "$(realpath "$RR_TASK2A0_ROOT")/ReleaseRadarTests/Fixtures"
for version in SchemaV10 SchemaV11; do
  RR_TASK2A0_DIR="$RR_TASK2A0_FIXTURE_PARENT/$version"
  rr_task2a0_require_directory "$RR_TASK2A0_DIR"
  test "$(realpath "$RR_TASK2A0_DIR")" = \
    "$(realpath "$RR_TASK2A0_FIXTURE_PARENT")/$version"
done
for fixture_path in \
  "$RR_TASK2A0_FIXTURE_PARENT/SchemaV10/release-radar-v10.sqlite" \
  "$RR_TASK2A0_FIXTURE_PARENT/SchemaV10/SHA256SUMS" \
  "$RR_TASK2A0_FIXTURE_PARENT/SchemaV11/release-radar-v11.sqlite" \
  "$RR_TASK2A0_FIXTURE_PARENT/SchemaV11/SHA256SUMS"; do
  rr_task2a0_require_file "$fixture_path"
done
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite)" = "278528"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS | awk '{print $1}')" = \
  "c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite)" = "348160"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite | awk '{print $1}')" = \
  "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS | awk '{print $1}')" = \
  "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"
```

Expected: every check exits 0. Any mismatch is Required and stops before RED;
do not repair or regenerate a fixture in this prerequisite.

### Step 2: Historical RED — the Xcode membership collision

Use a new unique parent and an initially absent DerivedData path. This RED is
not Task 2A's missing-gate generator RED: it runs `build-for-testing`, executes
no test, provides no generator environment, opens no SQLite database, and
creates no fixture or attachment.

The Implementer ran the `xcodebuild` invocation below once from the repository
root. The surrounding checks now state the corrected oracle that the retained
logs satisfy; they do not authorize executing the block again:

```bash
set -euo pipefail
export LC_ALL=C
umask 077
RR_TASK2A0_RED_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a0-red.XXXXXX)"
RR_TASK2A0_RED_DERIVED="$RR_TASK2A0_RED_PARENT/DerivedData"
RR_TASK2A0_RED_LOG="$RR_TASK2A0_RED_PARENT/build-for-testing.log"
RR_TASK2A0_RED_NORMALIZED="$RR_TASK2A0_RED_PARENT/build-for-testing-normalized.log"
test -d "$RR_TASK2A0_RED_PARENT"
test ! -L "$RR_TASK2A0_RED_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_RED_PARENT")" = "Directory"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_RED_PARENT")" = "700"
test ! -e "$RR_TASK2A0_RED_DERIVED"
test ! -L "$RR_TASK2A0_RED_DERIVED"
test ! -e "$RR_TASK2A0_RED_LOG"
test ! -L "$RR_TASK2A0_RED_LOG"
test ! -e "$RR_TASK2A0_RED_NORMALIZED"
test ! -L "$RR_TASK2A0_RED_NORMALIZED"
set +e
xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK2A0_RED_DERIVED" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  >"$RR_TASK2A0_RED_LOG" 2>&1
RR_TASK2A0_RED_STATUS=$?
set -e
test "$RR_TASK2A0_RED_STATUS" = "65"
test -f "$RR_TASK2A0_RED_LOG"
test ! -L "$RR_TASK2A0_RED_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_RED_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_RED_LOG")" = "600"
RR_TASK2A0_EXPECTED_OUTPUT="$RR_TASK2A0_RED_DERIVED/Build/Products/Debug/ReleaseRadar.app/Contents/PlugIns/ReleaseRadarTests.xctest/Contents/Resources/SHA256SUMS"
RR_TASK2A0_EXPECTED_ERROR="error: Multiple commands produce '$RR_TASK2A0_EXPECTED_OUTPUT'"
RR_TASK2A0_EXPECTED_V10_NOTE="note: Target 'ReleaseRadarTests' (project 'ReleaseRadar') has copy command from '$PWD/ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS' to '$RR_TASK2A0_EXPECTED_OUTPUT'"
RR_TASK2A0_EXPECTED_V11_NOTE="note: Target 'ReleaseRadarTests' (project 'ReleaseRadar') has copy command from '$PWD/ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' to '$RR_TASK2A0_EXPECTED_OUTPUT'"

# Xcode indents note diagnostics. Remove only that presentation indentation;
# the complete normalized diagnostic text remains exact.
sed -E 's/^[[:space:]]+//' "$RR_TASK2A0_RED_LOG" \
  > "$RR_TASK2A0_RED_NORMALIZED"
test -f "$RR_TASK2A0_RED_NORMALIZED"
test ! -L "$RR_TASK2A0_RED_NORMALIZED"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_RED_NORMALIZED")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_RED_NORMALIZED")" = "600"

# Do not print a matching line: a marker hit is sensitive evidence and fails
# closed. The pattern is intentionally narrow to credentials and private keys.
# Quiet rg status 1 is the sole pass state; a match or scanner failure rejects.
RR_TASK2A0_SECRET_MARKERS='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|authorization:[[:space:]]*(bearer|basic)[[:space:]]+|(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'
set +e
rg -q -i -e "$RR_TASK2A0_SECRET_MARKERS" \
  "$RR_TASK2A0_RED_LOG" "$RR_TASK2A0_RED_NORMALIZED"
RR_TASK2A0_RED_MARKER_STATUS=$?
set -e
test "$RR_TASK2A0_RED_MARKER_STATUS" = "1"
RR_TASK2A0_RED_LOG_SHA256="$(shasum -a 256 "$RR_TASK2A0_RED_LOG" | awk '{print $1}')"
RR_TASK2A0_RED_NORMALIZED_SHA256="$(shasum -a 256 \
  "$RR_TASK2A0_RED_NORMALIZED" | awk '{print $1}')"
test -n "$RR_TASK2A0_RED_LOG_SHA256"
test -n "$RR_TASK2A0_RED_NORMALIZED_SHA256"

# Exactly one error diagnostic exists, and it is exactly the authorized
# one-output collision. This rejects every unrelated error and every additional
# collision output.
test "$(grep -c 'error:' "$RR_TASK2A0_RED_LOG")" = "1"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_ERROR" "$RR_TASK2A0_RED_LOG")" = "1"
test "$(grep -Fc 'Multiple commands produce' "$RR_TASK2A0_RED_LOG")" = "1"

# Exactly two copy-command producer notes exist globally, both target that
# output, and each exact source appears once. The global count rejects an
# additional producer note even if it targets another output.
test "$(grep -Fc 'has copy command from' \
  "$RR_TASK2A0_RED_NORMALIZED")" = "2"
test "$(awk -v expected_output="to '$RR_TASK2A0_EXPECTED_OUTPUT'" \
  'index($0, "has copy command from") > 0 && index($0, expected_output) > 0 \
    { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A0_RED_NORMALIZED")" = "2"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_V10_NOTE" \
  "$RR_TASK2A0_RED_NORMALIZED")" = "1"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_V11_NOTE" \
  "$RR_TASK2A0_RED_NORMALIZED")" = "1"
test "$(awk '$0 == "** TEST BUILD FAILED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_RED_LOG")" = "1"
test "$(awk '$0 ~ /^\*\* .*BUILD SUCCEEDED \*\*$/ { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_RED_LOG")" = "0"
```

Accepted RED requires exit `65`, exactly one `error:` line equal to the
dynamic expected `Multiple commands produce '<output>'` diagnostic, and
exactly two normalized copy-command notes: one exact SchemaV10 producer and one
exact SchemaV11 producer for that output. The normalized log must contain
exactly two `has copy command from` lines globally, so a producer targeting any
other output also rejects. The raw log must contain exactly one exact
`** TEST BUILD FAILED **` line, and every build-success marker must be absent.
Any extra error, collision output,
producer, duplicate note, signing failure, compilation failure, dependency
failure, permission failure, missing-file failure, or unrelated resource
failure is not accepted RED and blocks implementation. Do not rerun Task 2A's
generator RED under any outcome. Retain the mode-`700` RED parent and both
mode-`600` logs through independent postimplementation review, disclose the
parent and log paths as temporary evidence, never stage or transmit them, and
do not delete them without owner authorization.

### Step 3: Historical one authorized project edit

The Implementer used `apply_patch` to insert only
`Fixtures/SchemaV11/SHA256SUMS` in the existing one-line
`membershipExceptions` list for exception set
`A90000000000000000000003`. That edit is complete; do not reapply, reformat,
or touch another project object during correction.

### Step 4: Historical project parse and exact authorized-diff gate

The Implementer ran this `/bin/bash` block before GREEN. Step 7 performs the
post-correction reconstruction without creating new build evidence:

```bash
set -euo pipefail
export LC_ALL=C
umask 077
RR_TASK2A0_PROJECT=ReleaseRadar.xcodeproj/project.pbxproj
RR_TASK2A0_SCHEME=ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme
RR_TASK2A0_PLANNING_SHA="$(git log -1 --format=%H -- \
  docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md)"
test -n "$RR_TASK2A0_PLANNING_SHA"
test "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_PROJECT")" = \
  "736654a040a90603ad322068fa48fa428acca3fb"
test "$(git show "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_PROJECT" | \
  rg -o 'Fixtures/SchemaV11/SHA256SUMS' | wc -l | tr -d ' ')" = "0"
test "$(rg -o 'Fixtures/SchemaV11/SHA256SUMS' "$RR_TASK2A0_PROJECT" | \
  wc -l | tr -d ' ')" = "1"
test "$(rg -o 'Fixtures/SchemaV10/SHA256SUMS' "$RR_TASK2A0_PROJECT" | \
  wc -l | tr -d ' ')" = "0"
for preserved in \
  Fixtures/CodexPluginLifecycle/v1/.agents/plugins/marketplace.json \
  Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.codex-plugin/plugin.json \
  Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.mcp.json \
  Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/skills/release-radar/SKILL.md \
  Fixtures/CodexPluginLifecycle/v2/.agents/plugins/marketplace.json \
  Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/.codex-plugin/plugin.json \
  Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/.mcp.json \
  Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/skills/release-radar/SKILL.md; do
  test "$(rg -F -o "$preserved" "$RR_TASK2A0_PROJECT" | wc -l | tr -d ' ')" = "1"
done

RR_TASK2A0_GATE_PARENT="$(mktemp -d /tmp/release-radar-task2a0-project-gate.XXXXXX)"
test -d "$RR_TASK2A0_GATE_PARENT"
test ! -L "$RR_TASK2A0_GATE_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_GATE_PARENT")" = "Directory"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_GATE_PARENT")" = "700"
RR_TASK2A0_EXPECTED="$RR_TASK2A0_GATE_PARENT/project.pbxproj.expected"
RR_TASK2A0_PROJECT_LIST="$RR_TASK2A0_GATE_PARENT/project-list.json"
test ! -e "$RR_TASK2A0_EXPECTED"
test ! -L "$RR_TASK2A0_EXPECTED"
test ! -e "$RR_TASK2A0_PROJECT_LIST"
test ! -L "$RR_TASK2A0_PROJECT_LIST"
git show "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_PROJECT" | perl -0pe \
  's#Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/skills/release-radar/SKILL\.md, \); target = A20000000000000000000004#Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/skills/release-radar/SKILL.md, Fixtures/SchemaV11/SHA256SUMS, ); target = A20000000000000000000004#' \
  > "$RR_TASK2A0_EXPECTED"
test -f "$RR_TASK2A0_EXPECTED"
test ! -L "$RR_TASK2A0_EXPECTED"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_EXPECTED")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_EXPECTED")" = "600"
cmp "$RR_TASK2A0_EXPECTED" "$RR_TASK2A0_PROJECT"
plutil -lint "$RR_TASK2A0_PROJECT"
xcodebuild -list -json -project ReleaseRadar.xcodeproj \
  > "$RR_TASK2A0_PROJECT_LIST"
test -f "$RR_TASK2A0_PROJECT_LIST"
test ! -L "$RR_TASK2A0_PROJECT_LIST"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_PROJECT_LIST")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_PROJECT_LIST")" = "600"
plutil -convert json -o - "$RR_TASK2A0_PROJECT_LIST" >/dev/null
git diff --check -- "$RR_TASK2A0_PROJECT"
git diff --cached --exit-code
test "$(git diff --name-only)" = "$RR_TASK2A0_PROJECT"
test "$(git status --short --untracked-files=normal)" = \
  "$(printf ' M %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/')"
test "$(git status --short --untracked-files=all)" = \
  "$(printf ' M %s\n?? %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"

test "$(git hash-object "$RR_TASK2A0_SCHEME")" = \
  "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME")"
cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME") \
  "$RR_TASK2A0_SCHEME"
RR_TASK2A0_CURRENT_ENTITLEMENTS="$(git ls-files '*.entitlements' | sort)"
RR_TASK2A0_CHECKPOINT_ENTITLEMENTS="$(git ls-tree -r --name-only \
  "$RR_TASK2A0_PLANNING_SHA" | awk '/[.]entitlements$/ { print }' | sort)"
test -n "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
test "$RR_TASK2A0_CURRENT_ENTITLEMENTS" = \
  "$RR_TASK2A0_CHECKPOINT_ENTITLEMENTS"
while IFS= read -r entitlement_file; do
  test "$(git hash-object "$entitlement_file")" = \
    "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$entitlement_file")"
  cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$entitlement_file") \
    "$entitlement_file"
done <<< "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
git diff --exit-code "$RR_TASK2A0_PLANNING_SHA" -- \
  "$RR_TASK2A0_SCHEME" \
  '*.entitlements'
git diff --no-ext-diff --minimal -- "$RR_TASK2A0_PROJECT"
```

`cmp` is the controlling authorized-diff check: it constructs the only allowed
post-edit project file from the planning checkpoint and requires byte equality.
The global status/index gate rejects every tracked change outside that project
file, including schemes and entitlements, and the blob comparisons separately
pin the shared scheme and complete repository-owned entitlement inventory. Any
other change is Required and stops before GREEN.

### Step 5: Historical GREEN — the identical build-for-testing invocation

The Implementer ran the `xcodebuild` invocation below once with a different
unique parent and an initially absent DerivedData path. The command and all
build arguments were identical to RED. The surrounding checks now state the
corrected oracle that the retained log satisfies; this block must not be run
again:

```bash
set -euo pipefail
umask 077
RR_TASK2A0_GREEN_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a0-green.XXXXXX)"
RR_TASK2A0_GREEN_DERIVED="$RR_TASK2A0_GREEN_PARENT/DerivedData"
RR_TASK2A0_GREEN_LOG="$RR_TASK2A0_GREEN_PARENT/build-for-testing.log"
test -d "$RR_TASK2A0_GREEN_PARENT"
test ! -L "$RR_TASK2A0_GREEN_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_GREEN_PARENT")" = "Directory"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_GREEN_PARENT")" = "700"
test ! -e "$RR_TASK2A0_GREEN_DERIVED"
test ! -L "$RR_TASK2A0_GREEN_DERIVED"
test ! -e "$RR_TASK2A0_GREEN_LOG"
test ! -L "$RR_TASK2A0_GREEN_LOG"
xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK2A0_GREEN_DERIVED" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  >"$RR_TASK2A0_GREEN_LOG" 2>&1
test -f "$RR_TASK2A0_GREEN_LOG"
test ! -L "$RR_TASK2A0_GREEN_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_GREEN_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A0_GREEN_LOG")" = "600"
RR_TASK2A0_SECRET_MARKERS='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|authorization:[[:space:]]*(bearer|basic)[[:space:]]+|(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'
set +e
rg -q -i -e "$RR_TASK2A0_SECRET_MARKERS" "$RR_TASK2A0_GREEN_LOG"
RR_TASK2A0_GREEN_MARKER_STATUS=$?
set -e
test "$RR_TASK2A0_GREEN_MARKER_STATUS" = "1"
RR_TASK2A0_GREEN_LOG_SHA256="$(shasum -a 256 \
  "$RR_TASK2A0_GREEN_LOG" | awk '{print $1}')"
test -n "$RR_TASK2A0_GREEN_LOG_SHA256"
test "$(awk '$0 == "** TEST BUILD SUCCEEDED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "1"
test "$(awk '$0 == "** TEST BUILD FAILED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "0"
test "$(awk 'index($0, "Multiple commands produce") > 0 { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "0"
test "$(awk 'NF { final = $0 } END { \
  print(final == "** TEST BUILD SUCCEEDED **" ? 1 : 0) }' \
  "$RR_TASK2A0_GREEN_LOG")" = "1"
RR_TASK2A0_BUNDLED_SUM="$RR_TASK2A0_GREEN_DERIVED/Build/Products/Debug/ReleaseRadar.app/Contents/PlugIns/ReleaseRadarTests.xctest/Contents/Resources/SHA256SUMS"
test -f "$RR_TASK2A0_BUNDLED_SUM"
test ! -L "$RR_TASK2A0_BUNDLED_SUM"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_BUNDLED_SUM")" = "Regular File"
cmp ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS "$RR_TASK2A0_BUNDLED_SUM"
```

Accepted GREEN: exit `0`, exactly one `** TEST BUILD SUCCEEDED **` line as the
final nonempty line, zero `** TEST BUILD FAILED **` lines, zero collision
diagnostics, and a sole built `SHA256SUMS` byte-identical to SchemaV10. The
SchemaV10 manifest's existing target membership is therefore preserved. Retain the mode-`700`
GREEN parent and mode-`600` raw log through independent postimplementation
review, disclose their paths as temporary evidence, never stage or transmit
them, and do not delete them without owner authorization.

### Step 6: Historical source-path, fixture-identity, and final boundary checks

The Implementer ran this `/bin/bash` block after GREEN without running tests.
Step 7 repeats the durable checks from the retained state:

```bash
set -euo pipefail
export LC_ALL=C
RR_TASK2A0_TEST_SOURCE=ReleaseRadarTests/StoreAcceptanceTests.swift
RR_TASK2A0_PROJECT=ReleaseRadar.xcodeproj/project.pbxproj
RR_TASK2A0_SCHEME=ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme
RR_TASK2A0_PLANNING_SHA="$(git log -1 --format=%H -- \
  docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md)"
test "$(git hash-object "$RR_TASK2A0_TEST_SOURCE")" = \
  "7041bd69a9a8349e7164eaee21a11858e9ebd87d"
test "$(rg -F -o 'URL(fileURLWithPath: #filePath).deletingLastPathComponent()' \
  "$RR_TASK2A0_TEST_SOURCE" | wc -l | tr -d ' ')" = "1"
test "$(rg -F -o 'Fixtures/SchemaV10' "$RR_TASK2A0_TEST_SOURCE" | \
  wc -l | tr -d ' ')" = "1"
RR_TASK2A0_SOURCE_TEST_DIR="$(dirname "$(realpath "$RR_TASK2A0_TEST_SOURCE")")"
test "$RR_TASK2A0_SOURCE_TEST_DIR" = \
  "$(realpath ReleaseRadarTests)"
for relative in \
  Fixtures/SchemaV10/release-radar-v10.sqlite \
  Fixtures/SchemaV10/SHA256SUMS \
  Fixtures/SchemaV11/release-radar-v11.sqlite \
  Fixtures/SchemaV11/SHA256SUMS; do
  test -f "$RR_TASK2A0_SOURCE_TEST_DIR/$relative"
  test ! -L "$RR_TASK2A0_SOURCE_TEST_DIR/$relative"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A0_SOURCE_TEST_DIR/$relative")" = \
    "Regular File"
done
(cd "$RR_TASK2A0_SOURCE_TEST_DIR/Fixtures/SchemaV10" && shasum -a 256 -c SHA256SUMS)
(cd "$RR_TASK2A0_SOURCE_TEST_DIR/Fixtures/SchemaV11" && shasum -a 256 -c SHA256SUMS)
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite)" = "278528"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS | awk '{print $1}')" = \
  "c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite)" = "348160"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite | awk '{print $1}')" = \
  "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS | awk '{print $1}')" = \
  "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"

git diff --cached --exit-code
git diff --exit-code -- \
  ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite \
  ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS \
  ReleaseRadarTests/StoreAcceptanceTests.swift \
  ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
test "$(git diff --name-only)" = "$RR_TASK2A0_PROJECT"
test "$(git status --short --untracked-files=normal)" = \
  "$(printf ' M %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/')"
test "$(git status --short --untracked-files=all)" = \
  "$(printf ' M %s\n?? %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"

test "$(git hash-object "$RR_TASK2A0_SCHEME")" = \
  "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME")"
cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$RR_TASK2A0_SCHEME") \
  "$RR_TASK2A0_SCHEME"
RR_TASK2A0_CURRENT_ENTITLEMENTS="$(git ls-files '*.entitlements' | sort)"
RR_TASK2A0_CHECKPOINT_ENTITLEMENTS="$(git ls-tree -r --name-only \
  "$RR_TASK2A0_PLANNING_SHA" | awk '/[.]entitlements$/ { print }' | sort)"
test -n "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
test "$RR_TASK2A0_CURRENT_ENTITLEMENTS" = \
  "$RR_TASK2A0_CHECKPOINT_ENTITLEMENTS"
while IFS= read -r entitlement_file; do
  test "$(git hash-object "$entitlement_file")" = \
    "$(git rev-parse "$RR_TASK2A0_PLANNING_SHA:$entitlement_file")"
  cmp <(git show "$RR_TASK2A0_PLANNING_SHA:$entitlement_file") \
    "$entitlement_file"
done <<< "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
git diff --exit-code "$RR_TASK2A0_PLANNING_SHA" -- \
  "$RR_TASK2A0_SCHEME" \
  '*.entitlements'
```

The `#filePath` assertion and the canonical source-directory checks prove the
membership exception changes only bundle copying. Both manifests remain
available from the source tree. No source edit is needed or authorized.

Historical execution repeated the complete Step 4 gate after GREEN, including
the exact reconstructed-project `cmp`, parse, global status/index boundary, and
scheme/entitlement comparisons. Step 6 repeated every SchemaV10 and SchemaV11
size/digest pin and local manifest check from Step 1. Step 7 now supersedes
those post-GREEN checks for correction review; do not rerun the historical
blocks.

### Step 7: Post-execution correction authority and retained-evidence gate

This is the only executable continuation after the correction checkpoint is
committed, pushed, and remote-exact. Run it once in `/bin/bash` from the
canonical repository root before independent postimplementation review. It is
read-only: it contains no `xcodebuild`, fixture generator, file write, staging,
commit, push, deletion, or external mutation command.

```bash
set -euo pipefail
export LC_ALL=C
RR_TASK2A0_ROOT="$(git rev-parse --show-toplevel)"
RR_TASK2A0_BRANCH=codex/release-radar-mvp
RR_TASK2A0_INITIAL_SHA=fccab15dacef8ad4452743a7e75ebf8773304cf3
RR_TASK2A0_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md
RR_TASK2A0_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A0_LEDGER=docs/delivery/progress.md
RR_TASK2A0_PROJECT=ReleaseRadar.xcodeproj/project.pbxproj
RR_TASK2A0_SCHEME=ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme
RR_TASK2A0_RED_PARENT=/tmp/release-radar-rr-r10-task2a0-red.ftQACG
RR_TASK2A0_RED_LOG="$RR_TASK2A0_RED_PARENT/build-for-testing.log"
RR_TASK2A0_RED_NORMALIZED="$RR_TASK2A0_RED_PARENT/build-for-testing-normalized.log"
RR_TASK2A0_GREEN_PARENT=/tmp/release-radar-rr-r10-task2a0-green.Fq0sWc
RR_TASK2A0_GREEN_LOG="$RR_TASK2A0_GREEN_PARENT/build-for-testing.log"

test "$(pwd -P)" = "$(realpath "$RR_TASK2A0_ROOT")"
test "$(git branch --show-current)" = "$RR_TASK2A0_BRANCH"
RR_TASK2A0_BRIEF_DIGEST="$(shasum -a 256 "$RR_TASK2A0_BRIEF" | awk '{print $1}')"
test "$(awk -v brief="$RR_TASK2A0_BRIEF" \
  '$2 == brief { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A0_REGISTRY")" = "1"
RR_TASK2A0_EXPECTED_REGISTRY_ENTRY="$RR_TASK2A0_BRIEF_DIGEST  $RR_TASK2A0_BRIEF"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_REGISTRY_ENTRY" \
  "$RR_TASK2A0_REGISTRY")" = "1"
shasum -a 256 -c "$RR_TASK2A0_REGISTRY"

RR_TASK2A0_CORRECTION_SHA="$(git log -1 --format=%H -- "$RR_TASK2A0_BRIEF")"
test "$(git rev-parse HEAD)" = "$RR_TASK2A0_CORRECTION_SHA"
test "$(git rev-list --parents -n 1 "$RR_TASK2A0_CORRECTION_SHA")" = \
  "$RR_TASK2A0_CORRECTION_SHA $RR_TASK2A0_INITIAL_SHA"
test "$(git rev-list --count \
  "$RR_TASK2A0_INITIAL_SHA..$RR_TASK2A0_CORRECTION_SHA")" = "1"
RR_TASK2A0_EXPECTED_INVENTORY="$(printf '%s\n' \
  "$RR_TASK2A0_BRIEF" \
  "$RR_TASK2A0_REGISTRY" \
  "$RR_TASK2A0_LEDGER" | sort)"
RR_TASK2A0_ACTUAL_INVENTORY="$(git diff-tree --no-commit-id --name-only -r \
  "$RR_TASK2A0_CORRECTION_SHA" | sort)"
test "$RR_TASK2A0_ACTUAL_INVENTORY" = "$RR_TASK2A0_EXPECTED_INVENTORY"
for correction_file in \
  "$RR_TASK2A0_BRIEF" \
  "$RR_TASK2A0_REGISTRY" \
  "$RR_TASK2A0_LEDGER"; do
  test "$(git hash-object "$correction_file")" = \
    "$(git rev-parse "$RR_TASK2A0_CORRECTION_SHA:$correction_file")"
  cmp <(git show "$RR_TASK2A0_CORRECTION_SHA:$correction_file") \
    "$correction_file"
done

test "$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = \
  "origin/$RR_TASK2A0_BRANCH"
test "$(git rev-parse '@{upstream}')" = "$RR_TASK2A0_CORRECTION_SHA"
RR_TASK2A0_REMOTE_LINES="$(git ls-remote --heads origin \
  "refs/heads/$RR_TASK2A0_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2A0_REMOTE_LINES" | \
  awk 'NF { count += 1 } END { print count + 0 }')" = "1"
test "$(printf '%s\n' "$RR_TASK2A0_REMOTE_LINES" | awk '{print $1}')" = \
  "$RR_TASK2A0_CORRECTION_SHA"
read -r RR_TASK2A0_AHEAD RR_TASK2A0_BEHIND < <(
  git rev-list --left-right --count HEAD...'@{upstream}'
)
test "$RR_TASK2A0_AHEAD" = "0"
test "$RR_TASK2A0_BEHIND" = "0"

git diff --cached --exit-code
test "$(git diff --name-only)" = "$RR_TASK2A0_PROJECT"
test "$(git status --short --untracked-files=normal)" = \
  "$(printf ' M %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/')"
test "$(git status --short --untracked-files=all)" = \
  "$(printf ' M %s\n?? %s\n?? %s' "$RR_TASK2A0_PROJECT" \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"
test "$(git rev-parse \
  "$RR_TASK2A0_INITIAL_SHA:$RR_TASK2A0_PROJECT")" = \
  "736654a040a90603ad322068fa48fa428acca3fb"
test "$(git rev-parse \
  "$RR_TASK2A0_CORRECTION_SHA:$RR_TASK2A0_PROJECT")" = \
  "736654a040a90603ad322068fa48fa428acca3fb"
test "$(git hash-object "$RR_TASK2A0_PROJECT")" = \
  "2b984d44e5b73602bf04b18b761d308761de789c"
cmp <(git show "$RR_TASK2A0_CORRECTION_SHA:$RR_TASK2A0_PROJECT" | perl -0pe \
  's#Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/skills/release-radar/SKILL\.md, \); target = A20000000000000000000004#Fixtures/CodexPluginLifecycle/v2/plugins/release-radar/skills/release-radar/SKILL.md, Fixtures/SchemaV11/SHA256SUMS, ); target = A20000000000000000000004#') \
  "$RR_TASK2A0_PROJECT"
test "$(rg -F -o 'Fixtures/SchemaV11/SHA256SUMS' \
  "$RR_TASK2A0_PROJECT" | wc -l | tr -d ' ')" = "1"
test "$(rg -F -o 'Fixtures/SchemaV10/SHA256SUMS' \
  "$RR_TASK2A0_PROJECT" | wc -l | tr -d ' ')" = "0"
git diff --check -- "$RR_TASK2A0_PROJECT"

test "$(git hash-object "$RR_TASK2A0_SCHEME")" = \
  "$(git rev-parse "$RR_TASK2A0_CORRECTION_SHA:$RR_TASK2A0_SCHEME")"
cmp <(git show "$RR_TASK2A0_CORRECTION_SHA:$RR_TASK2A0_SCHEME") \
  "$RR_TASK2A0_SCHEME"
RR_TASK2A0_CURRENT_ENTITLEMENTS="$(git ls-files '*.entitlements' | sort)"
RR_TASK2A0_CORRECTION_ENTITLEMENTS="$(git ls-tree -r --name-only \
  "$RR_TASK2A0_CORRECTION_SHA" | awk '/[.]entitlements$/ { print }' | sort)"
test -n "$RR_TASK2A0_CURRENT_ENTITLEMENTS"
test "$RR_TASK2A0_CURRENT_ENTITLEMENTS" = \
  "$RR_TASK2A0_CORRECTION_ENTITLEMENTS"
while IFS= read -r entitlement_file; do
  test "$(git hash-object "$entitlement_file")" = \
    "$(git rev-parse "$RR_TASK2A0_CORRECTION_SHA:$entitlement_file")"
  cmp <(git show "$RR_TASK2A0_CORRECTION_SHA:$entitlement_file") \
    "$entitlement_file"
done <<< "$RR_TASK2A0_CURRENT_ENTITLEMENTS"

rr_task2a0_require_regular() {
  test -f "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Regular File"
}
rr_task2a0_require_directory() {
  test -d "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Directory"
}
RR_TASK2A0_FIXTURE_PARENT="$RR_TASK2A0_ROOT/ReleaseRadarTests/Fixtures"
rr_task2a0_require_directory "$RR_TASK2A0_FIXTURE_PARENT"
test "$(realpath "$RR_TASK2A0_FIXTURE_PARENT")" = \
  "$RR_TASK2A0_ROOT/ReleaseRadarTests/Fixtures"
for fixture_version in SchemaV10 SchemaV11; do
  RR_TASK2A0_FIXTURE_DIR="$RR_TASK2A0_FIXTURE_PARENT/$fixture_version"
  rr_task2a0_require_directory "$RR_TASK2A0_FIXTURE_DIR"
  test "$(realpath "$RR_TASK2A0_FIXTURE_DIR")" = \
    "$RR_TASK2A0_FIXTURE_PARENT/$fixture_version"
done
for fixture_file in \
  ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite \
  ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS \
  ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite \
  ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS; do
  rr_task2a0_require_regular "$fixture_file"
done
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite)" = "278528"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS | awk '{print $1}')" = \
  "c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite)" = "348160"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite | awk '{print $1}')" = \
  "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS)" = "91"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS | awk '{print $1}')" = \
  "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"

for evidence_parent in \
  "$RR_TASK2A0_RED_PARENT" \
  "$RR_TASK2A0_GREEN_PARENT"; do
  test -d "$evidence_parent"
  test ! -L "$evidence_parent"
  test "$(/usr/bin/stat -f '%HT' "$evidence_parent")" = "Directory"
  test "$(/usr/bin/stat -f '%Lp' "$evidence_parent")" = "700"
done
for evidence_file in \
  "$RR_TASK2A0_RED_LOG" \
  "$RR_TASK2A0_RED_NORMALIZED" \
  "$RR_TASK2A0_GREEN_LOG"; do
  rr_task2a0_require_regular "$evidence_file"
  test "$(/usr/bin/stat -f '%Lp' "$evidence_file")" = "600"
done
test "$(shasum -a 256 "$RR_TASK2A0_RED_LOG" | awk '{print $1}')" = \
  "ad3e40becf20b3dace25d62b32b675af68b5e5e350be5a34b66095a5efb5506f"
test "$(shasum -a 256 "$RR_TASK2A0_RED_NORMALIZED" | awk '{print $1}')" = \
  "477c93ae7b9fa312fed759fc6567974c7b277322fef4f993c6cf57d0c8f58d8c"
test "$(shasum -a 256 "$RR_TASK2A0_GREEN_LOG" | awk '{print $1}')" = \
  "fd09908beb4761a1029aaf91f2ce999f45665dfa9ed102428c1a26d282b488b0"

RR_TASK2A0_SECRET_MARKERS='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|authorization:[[:space:]]*(bearer|basic)[[:space:]]+|(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'
set +e
rg -q -i -e "$RR_TASK2A0_SECRET_MARKERS" \
  "$RR_TASK2A0_RED_LOG" "$RR_TASK2A0_RED_NORMALIZED"
RR_TASK2A0_RETAINED_RED_MARKER_STATUS=$?
rg -q -i -e "$RR_TASK2A0_SECRET_MARKERS" "$RR_TASK2A0_GREEN_LOG"
RR_TASK2A0_RETAINED_GREEN_MARKER_STATUS=$?
set -e
test "$RR_TASK2A0_RETAINED_RED_MARKER_STATUS" = "1"
test "$RR_TASK2A0_RETAINED_GREEN_MARKER_STATUS" = "1"

RR_TASK2A0_EXPECTED_OUTPUT="$RR_TASK2A0_RED_PARENT/DerivedData/Build/Products/Debug/ReleaseRadar.app/Contents/PlugIns/ReleaseRadarTests.xctest/Contents/Resources/SHA256SUMS"
RR_TASK2A0_EXPECTED_ERROR="error: Multiple commands produce '$RR_TASK2A0_EXPECTED_OUTPUT'"
RR_TASK2A0_EXPECTED_V10_NOTE="note: Target 'ReleaseRadarTests' (project 'ReleaseRadar') has copy command from '$RR_TASK2A0_ROOT/ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS' to '$RR_TASK2A0_EXPECTED_OUTPUT'"
RR_TASK2A0_EXPECTED_V11_NOTE="note: Target 'ReleaseRadarTests' (project 'ReleaseRadar') has copy command from '$RR_TASK2A0_ROOT/ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' to '$RR_TASK2A0_EXPECTED_OUTPUT'"
test "$(grep -c 'error:' "$RR_TASK2A0_RED_LOG")" = "1"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_ERROR" \
  "$RR_TASK2A0_RED_LOG")" = "1"
test "$(grep -Fc 'Multiple commands produce' "$RR_TASK2A0_RED_LOG")" = "1"
test "$(grep -Fc 'has copy command from' \
  "$RR_TASK2A0_RED_NORMALIZED")" = "2"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_V10_NOTE" \
  "$RR_TASK2A0_RED_NORMALIZED")" = "1"
test "$(grep -Fxc "$RR_TASK2A0_EXPECTED_V11_NOTE" \
  "$RR_TASK2A0_RED_NORMALIZED")" = "1"
test "$(awk '$0 == "** TEST BUILD FAILED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_RED_LOG")" = "1"
test "$(awk '$0 ~ /^\*\* .*BUILD SUCCEEDED \*\*$/ { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_RED_LOG")" = "0"

test "$(awk '$0 == "** TEST BUILD SUCCEEDED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "1"
test "$(awk '$0 == "** TEST BUILD FAILED **" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "0"
test "$(awk 'index($0, "Multiple commands produce") > 0 { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A0_GREEN_LOG")" = "0"
test "$(awk 'NF { final = $0 } END { \
  print(final == "** TEST BUILD SUCCEEDED **" ? 1 : 0) }' \
  "$RR_TASK2A0_GREEN_LOG")" = "1"
RR_TASK2A0_BUNDLED_SUM="$RR_TASK2A0_GREEN_PARENT/DerivedData/Build/Products/Debug/ReleaseRadar.app/Contents/PlugIns/ReleaseRadarTests.xctest/Contents/Resources/SHA256SUMS"
rr_task2a0_require_regular "$RR_TASK2A0_BUNDLED_SUM"
cmp ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS \
  "$RR_TASK2A0_BUNDLED_SUM"

rr_task2a0_require_ledger_fact() {
  set +e
  rg -q -F -- "$1" "$RR_TASK2A0_LEDGER"
  RR_TASK2A0_LEDGER_FACT_STATUS=$?
  set -e
  test "$RR_TASK2A0_LEDGER_FACT_STATUS" = "0"
}
rr_task2a0_require_ledger_fact \
  "Task 2A0 initial planning checkpoint: fccab15dacef8ad4452743a7e75ebf8773304cf3"
rr_task2a0_require_ledger_fact \
  "Task 2A0 retained RED: exit 65; marker scan 1; exact marker ** TEST BUILD FAILED **"
rr_task2a0_require_ledger_fact \
  "ad3e40becf20b3dace25d62b32b675af68b5e5e350be5a34b66095a5efb5506f"
rr_task2a0_require_ledger_fact \
  "477c93ae7b9fa312fed759fc6567974c7b277322fef4f993c6cf57d0c8f58d8c"
rr_task2a0_require_ledger_fact \
  "Task 2A0 retained GREEN: exit 0; marker scan 1; terminal ** TEST BUILD SUCCEEDED **"
rr_task2a0_require_ledger_fact \
  "fd09908beb4761a1029aaf91f2ce999f45665dfa9ed102428c1a26d282b488b0"
rr_task2a0_require_ledger_fact \
  "Task 2A0 current project blob: 2b984d44e5b73602bf04b18b761d308761de789c"
```

Expected: every check exits 0 without printing raw log content. The correction
commit is the single direct child of `fccab15…`, contains only the revised
brief, registry, and coordinator ledger, and is exact at HEAD, upstream, and
live remote with `0/0`. The only remaining worktree changes are the exact
authorized project diff and two preserved untracked SchemaV11 artifacts. The
gate binds the retained logs by mode and hash, silently re-verifies every
derivable collision, producer, secret-scan, exact RED marker, final GREEN
marker, and bundle fact,
and requires the ledger to carry the independently verified exit and prior
marker-scan statuses as sanitized facts. Exit statuses are process evidence,
not derivable from log bytes; they are never fabricated by rerunning a build.
Retain both restricted temporary parents through every independent review and
do not delete them without owner authorization.

## Happy path

The initial planning checkpoint `fccab15…`, historical Step 0, preimplementation
reviews, one RED, one authorized project edit, GREEN, and post-GREEN boundary
checks remain immutable evidence. The coordinator commits only this revised
brief, its one registry entry, and the sanitized ledger as the single direct
child of `fccab15…`, pushes it, and proves HEAD/upstream/live-remote equality at
`0/0`. Step 7 then binds the unchanged project blob, exact reconstructed diff,
fixtures, scheme, entitlements, retained log hashes/modes, collision oracle,
the exact RED marker, the final-nonempty GREEN marker, secret scans, and
SchemaV10 bundle comparison
without running a build or printing raw log content. All six independent
postimplementation roles return GO/Required 0 before the project-and-ledger
implementation checkpoint is committed, pushed, and verified remote-exact.
Task 2A remains paused until that checkpoint is complete.

## Non-happy paths and recovery

- If the revised brief digest/sole registry entry/full registry fails, the
  correction commit is not the single direct child of `fccab15…`, its inventory
  is not exactly brief/registry/coordinator ledger, or HEAD/upstream/live remote
  and `0/0` differ, stop. Do not amend the initial checkpoint, rerun a build,
  pull, push another change, or mutate external state to force a pass.
- If the worktree/index is not exactly the unstaged project diff plus the two
  untracked SchemaV11 files, the current project blob is not
  `2b984d44e5b73602bf04b18b761d308761de789c`, reconstructed comparison fails,
  or the shared scheme/entitlement inventory differs, stop. Do not repair or
  regenerate any completed implementation artifact in this correction.
- If either SchemaV10 or SchemaV11 directory/file is missing, a symlink, escapes
  its canonical parent, has a different size or digest, or fails its local
  checksum, stop. Do not regenerate, overwrite, delete, or normalize it.
- If retained RED does not have exact hashes, mode/type, exit `65` in the
  sanitized ledger, marker-scan status `1`, one exact collision error, exactly
  two producers, exactly one exact `** TEST BUILD FAILED **` marker, or zero
  success markers, return NO-GO. Do not rerun RED or any Task 2A generator.
- If either temporary parent is not a mode-`700` directory, any log is not a
  mode-`600` regular non-symlink, or either quiet marker scan returns anything
  other than status `1`, stop without printing or transmitting matching
  content. Status `0` means a credential, authorization header,
  password/token/secret assignment, or private-key marker was found; status
  greater than `1` means the scan itself failed and is never accepted as clean.
  Retain and disclose the restricted temporary path for owner-directed
  handling; do not delete it without owner authorization.
- If retained GREEN does not have its exact hash, mode/type, exit `0` in the
  sanitized ledger, marker-scan status `1`, exactly one terminal
  `** TEST BUILD SUCCEEDED **`, zero `** TEST BUILD FAILED **`, zero collision
  diagnostics, or the exact SchemaV10 bundled-manifest comparison, stop. Do
  not rerun GREEN, edit build settings, rename resources, or add a copy phase.
- If `#filePath` source lookup or either source fixture pair no longer resolves
  and verifies, stop. Do not compensate by loading fixtures from the bundle.
- If any SchemaV11 byte changes, leave Task 2A paused and return NO-GO. Do not
  recover by rerunning the generator or attachment export.
- During correction planning, only this brief and registry may be edited; only
  the coordinator may add `progress.md` to the correction commit. The completed
  project diff and fixtures remain unstaged. Preserve unrelated work and
  escalate any overlap.
- Do not delete the restricted RED/GREEN temporary evidence before all
  independent postimplementation reviews or without owner authorization.
- No failure authorizes Task 2A regression continuation, Task 2B, owner-data
  access, app launch/install, bridge/MCP use, live Ticket Tasks creation,
  RR-R10 mutation, Accepted-ticket change, notification, or external mutation.

## Activity and audit evidence requirements

This prerequisite is repository-only. It creates no Release Radar audit,
Activity row, review item, notification, command receipt, task-plan revision,
task completion, lane transition, blocker change, or owner-attention event.

Required repository evidence is:

- owner authorization and the independent blocker classification;
- initial planning checkpoint `fccab15…`, historical Step 0 pass, exact
  three-path inventory, `d8bda5…` parent, and pre-RED remote-exact state;
- computed revised brief SHA-256, its sole registry entry, full-registry
  verification, correction commit as the single direct child of `fccab15…`,
  exact brief/registry/ledger inventory, HEAD/upstream/live-remote equality,
  and `0/0`;
- current project blob `2b984d44e5b73602bf04b18b761d308761de789c`,
  exact reconstructed one-entry diff, empty index, exact project-plus-fixtures
  status, and unchanged shared scheme/entitlements;
- exact pre/post hashes, sizes, no-follow types, canonical containment, and
  local checksum results for both fixture pairs;
- exact historical signing-disabled RED command, absent DerivedData proof,
  exit `65`, exactly one exact expected `error:` line, and exactly two exact
  copy-command notes—one and only one for each pinned input—targeting the one
  expected output;
- retained RED parent `/tmp/release-radar-rr-r10-task2a0-red.ftQACG`, raw SHA
  `ad3e40becf20b3dace25d62b32b675af68b5e5e350be5a34b66095a5efb5506f`,
  normalized SHA
  `477c93ae7b9fa312fed759fc6567974c7b277322fef4f993c6cf57d0c8f58d8c`,
  mode/type checks, marker-scan status `1`, exactly one exact
  `** TEST BUILD FAILED **`, zero success markers, and temporary retention;
- exact one-entry project diff, reconstructed-file `cmp`, project parse, and
  preserved unrelated exception inventory;
- exact historical argument-identical signing-disabled GREEN command, absent
  DerivedData proof, exit `0`, retained parent
  `/tmp/release-radar-rr-r10-task2a0-green.Fq0sWc`, raw SHA
  `fd09908beb4761a1029aaf91f2ce999f45665dfa9ed102428c1a26d282b488b0`,
  mode/type, marker-scan status `1`, exactly one final
  `** TEST BUILD SUCCEEDED **`, zero `** TEST BUILD FAILED **`, collision
  absence, SchemaV10 bundled-manifest identity, and temporary retention;
- `#filePath` source-tree resolution and checksum results for both fixture
  versions;
- reviewer identities, dispositions, and Required/Optional/Out-of-scope counts;
- exact initial planning, correction, and implementation checkpoint
  inventories, commits, pushes, live remote SHAs, local/remote equality, and
  ahead/behind `0/0`; and
- explicit confirmation of no owner, Release Radar, accepted-artifact,
  fixture, generator, test-source, scheme, entitlement, build-setting, Task 2B,
  or external mutation.

Only sanitized facts, paths, modes, hashes, and diagnostic counts/text needed
for the accepted collision enter the ledger. Raw or normalized logs, owner
content, credentials, and key material must never be staged, copied into the
ledger, or transmitted.

## Acceptance criteria

- [ ] Owner authorization is recorded as approving only the SchemaV11
      manifest membership exception.
- [ ] Accepted design, ADR, plan, and Task 2A brief hashes remain exact and
      their contents are unchanged.
- [ ] This brief has exactly one canonical root-registry entry whose digest
      equals the file's computed SHA-256, and the complete registry verifies.
- [ ] Initial planning checkpoint
      `fccab15dacef8ad4452743a7e75ebf8773304cf3` and its historical Step 0,
      preimplementation GO/Required 0 reviews, three-path inventory,
      `d8bda5…` parent, clean tracked/index state, untracked SchemaV11 boundary,
      and remote `0/0` evidence remain truthful and unchanged.
- [ ] The correction checkpoint is the single direct child of `fccab15…`,
      contains exactly this revised brief, registry, and coordinator ledger,
      and is HEAD/upstream/live-remote exact at `0/0` before Step 7.
- [ ] Both SchemaV10 and SchemaV11 fixture pairs are regular non-symlink files,
      canonically contained, checksum-valid, and pinned to the exact pre-task
      sizes/digests before RED and through the repeated post-GREEN gate.
      SchemaV10 is exactly 278,528 bytes at
      `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`
      with a 91-byte manifest at
      `c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f`.
      SchemaV11 is exactly 348,160 bytes at
      `ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c`
      with a 91-byte manifest at
      `ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3`.
- [ ] Retained RED is only the exact historical signing-disabled
      `build-for-testing` invocation, exit `65`, marker-scan status `1`,
      contains exactly one `error:` line exactly equal to the dynamic expected
      `Multiple commands produce` diagnostic, and contains exactly two exact
      copy-command notes targeting that output: one and only one for SchemaV10
      and one and only one for SchemaV11. Its exact retained hashes/modes pass,
      exactly one exact `** TEST BUILD FAILED **` marker is present, and no
      success marker or unrelated failure is present.
- [ ] Task 2A's immutable generator RED, export, GREEN generator, and fixture
      generation are not rerun.
- [ ] The only implementation edit adds exactly one
      `Fixtures/SchemaV11/SHA256SUMS` entry to the existing ReleaseRadarTests
      membership exception set.
- [ ] SchemaV10 remains a test-target resource; all eight existing plugin
      membership exceptions and every unrelated project byte remain unchanged.
- [ ] Exact reconstructed-file `cmp`, `plutil -lint`, `xcodebuild -list`, and
      Git diff checks pass before and after GREEN.
- [ ] After the edit and through post-GREEN review, the sole tracked worktree
      diff is `ReleaseRadar.xcodeproj/project.pbxproj`, the index is empty,
      exact status is that modified project plus the one untracked SchemaV11
      directory, and the shared scheme plus every repository-owned entitlement
      remains byte/blob-identical to the planning checkpoint.
- [ ] Current project blob is exactly
      `2b984d44e5b73602bf04b18b761d308761de789c`; reconstruction from the
      correction-commit baseline proves only the one authorized membership
      exception changed.
- [ ] Retained GREEN is only the exact historical argument-identical
      signing-disabled build, exit `0`, marker-scan status `1`, exact retained
      hash/mode, exactly one final `** TEST BUILD SUCCEEDED **`, zero
      `** TEST BUILD FAILED **`, zero collision diagnostics, and a bundled
      manifest byte-identical to SchemaV10. No project build setting changes.
- [ ] `umask 077` precedes every temporary creation; RED/GREEN parents are
      mode-`700` directories; raw/normalized logs are mode-`600` regular
      non-symlinks; each quiet credential/private-key marker scan returns
      exactly status `1`, while status `0` or greater than `1` fails closed;
      sanitized facts and hashes only enter the ledger; and the disclosed
      temporary logs remain unstaged, untransmitted, and retained through
      review unless the owner authorizes deletion.
- [ ] Existing `#filePath`-based source-relative behavior remains unchanged,
      and both source fixture pairs resolve and verify without bundle lookup.
- [ ] Step 7 passes without printing raw content or executing a build. Step 0,
      RED, GREEN, Task 2A generators, and attachment export are not rerun.
- [ ] No source/test, fixture, design, ADR, plan, Task 2A brief/evidence,
      scheme, build setting, signing, entitlement, sandbox, owner data,
      Release Radar state, live Ticket Tasks plan, Task 2B, or external state
      changes.
- [ ] Fresh postimplementation Code Review, QA/Test, Architecture,
      Security/Privacy, TPM, and Delivery Management each return GO with
      Required 0.
- [ ] Implementation checkpoint inventory is exactly
      `ReleaseRadar.xcodeproj/project.pbxproj` and coordinator-owned
      `docs/delivery/progress.md`; the untracked SchemaV11 artifacts remain
      excluded and byte-identical.
- [ ] The accepted prerequisite implementation commit is pushed; local HEAD
      equals the live remote branch SHA with ahead/behind `0/0`.
- [ ] Task 2A remains paused until that remote-exact prerequisite checkpoint;
      only then may a fresh coordinator release Task 2A's existing regression
      continuation. Task 2B remains closed.

## Required independent reviews and role separation

Before RED:

The following completed reviews remain historical evidence and are not rerun
to authorize another build:

- Architecture verifies the correction is confined to test-target resource
  membership, preserves source-path fixture authority and SchemaV10 bundle
  membership, proves the scheme/entitlement boundary is unchanged, and
  requires no ADR change.
- TPM verifies the owner-authorized prerequisite is dependency-safe, bounded,
  and does not open Task 2A regression or Task 2B early.
- QA/Test verifies the build-only RED and identical GREEN commands; exactly one
  exact dynamic collision error; exactly two exact producer notes, one per
  pinned manifest and no others; rejection of any additional error, collision,
  producer, or unrelated failure; source-path behavior checks; and direct
  fixture identity checks.
- Delivery Management verifies exact checkpoint inventories, writer
  serialization, durable placement, the executable brief-derived authority
  gate, registered hash, pinned parent, exact pre-RED status, no partial
  commit, and both commit/push/live-remote gates.
- Security/Privacy verifies no-follow/canonical fixture checks, no fixture or
  owner-data mutation, unchanged project settings/scheme/sandbox/entitlements,
  argument-only signing disablement, restricted temporary parent/log modes,
  narrow fail-closed marker scans whose sole pass state is quiet `rg` status
  `1`, sanitized-only ledger evidence, no staging/transmission, and
  owner-controlled log deletion.

After the correction checkpoint and Step 7, a fresh Code Reviewer verifies the
exact project diff, global tracked/index/status boundary, and unchanged
scheme/entitlements; a fresh QA/Test verifier independently checks the
argument-identical RED/GREEN retained evidence, exact RED-marker and final
GREEN-marker oracle,
restricted log hashes/modes, fixture pins, and current project parse without
rerunning either build.
Architecture, Security/Privacy, TPM, and Delivery Management
independently disposition the completed prerequisite, including the retained
temporary-log handling, correction commit, and no-rerun boundary relevant to
their roles. The Planning agent does not implement; the Implementer does not
review or independently verify its own work. Required 0 is a hard gate.
Optional findings do not expand scope, and out-of-scope findings do not block
this prerequisite.

## Completion evidence required in `docs/delivery/progress.md`

Delivery Management must record:

- prerequisite status and dependency gate; owner authorization; Planning and
  Implementer identities; exact brief SHA; exact-one-entry and full-registry
  verification
- exact accepted design/ADR/plan/Task 2A hashes and confirmation they remain
  unchanged
- initial planning checkpoint `fccab15…`, its exact three paths, parent
  `d8bda5a035e0324acd90bcbe67036f8d217b18bf`, byte equality for those paths
  plus `project.pbxproj`, clean tracked/index state, exact untracked SchemaV11
  status, staged-diff inspection, commit, push, upstream/live remote SHA,
  local/remote equality, and ahead/behind `0/0`
- pre-RED and repeated post-edit/post-GREEN shared-scheme identity, exact
  repository-owned entitlement inventory, and per-file checkpoint blob/byte
  identity
- pre/post SchemaV10 and SchemaV11 file sizes, SHA-256 values, local checksum
  results, regular non-symlink types, canonical containment, and confirmation
  that the two SchemaV11 files stayed untracked and byte-identical
- exact historical signing-disabled RED command and mode-`700` retained parent
  `/tmp/release-radar-rr-r10-task2a0-red.ftQACG`, proof DerivedData was absent,
  mode-`600` raw/normalized log paths and hashes, exit `65`, exact quiet
  marker-scan status `1`, the exact sole `error:` diagnostic, the exact
  two normalized copy-command notes with one occurrence per input and no
  additional producer, the exact one test-bundle output, and proof no
  test/generator or Task 2A RED/export/GREEN generator ran, exactly one exact
  `** TEST BUILD FAILED **`, and zero success markers
- exact inserted exception path, exception-set/target IDs, reconstructed-file
  `cmp`, preserved eight existing exceptions, absent SchemaV10 exception,
  project parse results, and authorized Git diff
- exact historical argument-identical signing-disabled GREEN command and
  mode-`700` retained parent
  `/tmp/release-radar-rr-r10-task2a0-green.Fq0sWc`, proof DerivedData was
  absent, mode-`600` raw-log path and hash, exit `0`, exact quiet marker-scan
  status `1`, exactly one final `** TEST BUILD SUCCEEDED **`, zero
  `** TEST BUILD FAILED **`, collision absence, and byte identity of the sole
  bundled manifest to SchemaV10
- `StoreAcceptanceTests.swift` accepted blob identity and exact `#filePath`
  source-directory checks proving both source fixture pairs remain readable
  and checksum-valid
- all pre- and postimplementation reviewer identities, GO/NO-GO dispositions,
  and Required/Optional/Out-of-scope counts
- the Implementer's corrected `DONE_WITH_CONCERNS` disposition and the reason
  that the first report asserted the wrong literal marker
- disclosure that the restricted RED/GREEN logs necessarily name the canonical
  repository path, contain no owner content/credentials/key material, remained
  temporary/unstaged/untransmitted through review, and were not deleted absent
  explicit owner authorization; only sanitized facts and hashes are recorded
- explicit confirmation of no owner/app/bridge/board/ticket/Accepted-ticket/
  task-plan/notification/external mutation; no fixture, source, accepted
  artifact, or Task 2B change; and Task 2A still paused
- pre-review exact worktree status (modified project plus untracked SchemaV11
  only), empty index, current project blob, exact reconstructed diff, the
  correction checkpoint's exact three paths/direct-parent/remote evidence,
  Step 7 result, and explicit proof no build was rerun
- implementation checkpoint's exact two paths,
  staged-diff inspection, commit, push, `git ls-remote` SHA, local/remote
  equality, and ahead/behind `0/0`
- remaining risks/blockers and Task 2A regression continuation as the only
  next eligible action after exact remote verification

For the fail-closed Step 7 gate, `progress.md` must include each of these exact
sanitized facts without copying raw log content:

```text
Task 2A0 initial planning checkpoint: fccab15dacef8ad4452743a7e75ebf8773304cf3
Task 2A0 retained RED: exit 65; marker scan 1; exact marker ** TEST BUILD FAILED **
Task 2A0 retained GREEN: exit 0; marker scan 1; terminal ** TEST BUILD SUCCEEDED **
Task 2A0 current project blob: 2b984d44e5b73602bf04b18b761d308761de789c
```

It must also include each exact retained raw/normalized SHA-256 shown above.

## Initial planning, correction, and implementation checkpoint inventories

The completed initial planning checkpoint
`fccab15dacef8ad4452743a7e75ebf8773304cf3` contains exactly:

```text
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md
docs/delivery/task-briefs/SHA256SUMS
docs/delivery/progress.md
```

Its parent is `d8bda5a035e0324acd90bcbe67036f8d217b18bf`; historical
Step 0 passed before RED. Do not amend, replace, or rerun that checkpoint.
Neither the project file nor either SchemaV11 artifact entered it.

The correction checkpoint must be the single direct child of `fccab15…` and
contain exactly:

```text
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md
docs/delivery/task-briefs/SHA256SUMS
docs/delivery/progress.md
```

Inspect its staged diff, commit/push the complete reviewed correction, and
verify HEAD/upstream/live-remote equality plus ahead/behind `0/0`. The
completed `project.pbxproj` diff and both SchemaV11 artifacts remain unstaged
and outside the correction commit. Do not run a build. Step 7 is eligible only
after this exact remote checkpoint.

After Step 7 and every independent postimplementation GO/Required 0, the
implementation checkpoint contains exactly:

```text
ReleaseRadar.xcodeproj/project.pbxproj
docs/delivery/progress.md
```

Inspect the staged diff, commit/push the complete reviewed prerequisite, and
verify exact local/remote equality plus ahead/behind `0/0`. The SchemaV11
fixture and checksum remain untracked, byte-identical Task 2A outputs. The
restricted retained logs/build products remain temporary and outside every
commit but are not deleted without owner authorization. Task 2A remains paused
until this checkpoint is exact on the live remote. Task 2B remains closed until
Task 2A itself is independently accepted, committed, pushed, and remote-exact.
