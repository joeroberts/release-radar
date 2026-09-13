# Historical Phase 6 delivery coordination

Historical and non-authoritative. Preserved from the pre-closeout progress ledger.
Current state and authority live in [progress](../progress.md). Superseded pending
review and authorization statements below describe prior checkpoints only.
Final local Phase 6E source is `d1445dc033fca9056782c493ebd04184d58fbc67`;
independent review resolved all Required findings on September 11.

# Release Radar delivery state

## Current outcome and active task

Shared execution V1 and Phase 5A–5E are merged through
`e03a0dd2d104d4e7438421bce5fbdb14a8586112`. Their bounded peers are complete and
archived. The [Historical record](../archive/2026-09-10-phase5-shared-delivery-history.md)
preserves prior delivery, verification and authorization history.

Phase 6 local implementation is owner-authorized under the
[controlling plan](../plans/2026-09-10-phase6-outcomes-tasks-history.md), independently
reviewed at `22126cf560b6b4c527b20543a0f7064a91ac95ad` with no Required findings.
Orchestrator `01a08bd9-8fa1-74b3-bfa0-a5e657e70179` owns this ledger/catalog and
`codex/phase6-coordination` in worktree `3184`, from exact baseline
`e5372d170d9202d207922fe51f38bcf0827a2967`. Requested Astra Medium; runtime
settings are not independently exposed. Parent is `01a07e75-b254-72a1-be2a-3e97ac23baeb`.

Phase 6A History source is complete and independently reviewed. Final product/test
candidate is `fbbf138b00b0ff9e0b0de3ec33b269984288d30b`; evidence closeout is
`468d0bc97e4a866ee82ca4e5a95d409d63f4298c`, integrated locally. Its
[brief](../task-briefs/2026-09-10-phase6a-history/phase6a-history-brief.md) and
[canonical evidence](../evidence/2026-09-10-phase6a-history.md) retain the outcome,
checks, visual references and limitations. Seven Required findings were corrected;
the subsequent Required reset-state correction is now verified and merged in PR #44.

Chief assessment/review `01a08bdb-88c4-7f72-a529-8bdb0fe72443` (Astra High),
writer `01a08be3-987c-79a1-aa61-10520c4e8c97` (Sol High, bounded R4 escalation
Astra High), and independent reviewer `01a08c37-7f64-73b1-affd-7ea5d571eaaf`
(Astra High) are complete and archived. Their files/results are preserved. Writer and reviewer completed the same-outcome reset correction and are archived
again. Reviewer observed the intended red result then 2/2 passing model tests on
`ef190dc6063443956853903e2177328b746c1d85`; writer performed no launches.
Evidence closeout `da52b47ada7ec3d1b5966adf956d48e5268ee00b` was pushed and
PR #44 merged at `4f917b0c76fa74ebf4e0f4615cbf7e7dd4ac8597`.

Phase 6B Workspace Goals is complete and merged in PR #45. Independently approved source is
`4c751867b8d6e4f42e1a5edaa3df19e66718c679`; documentation closeout
`fb8a210f0afc604a5a5f7e7b377602a12353c2d2` is integrated. The
[brief](../task-briefs/2026-09-10-phase6b-goals/phase6b-goals-brief.md) and
[canonical evidence](../evidence/2026-09-10-phase6b-goals.md) preserve behavior,
verification, screenshots and limitations. The subsequent four CodeRabbit Required corrections passed direct checks and the same independent review.
Writer `01a08c9d-e36f-7a92-abba-69ade43678af` (Terra Medium, bounded escalation
Sol High) and reviewer `01a08cde-c8c9-70d1-9ba1-1e4a566cb52b` (Sol High) are
quiescent and archived again after completing the correction outcome.
Correction source `b7be24065dec287b7cb0b00ea39413418eb54387`, evidence tip
`d516a8b4c6c365001028d5a0113971697eff2ee2` and approval closeout
`c7c36425dbee669bedbbb3f3ce328a91853d5d8c` are preserved and merged. Direct tests
combine 17 passing cases with the corrected Settings fixture passing 1/1; all
five new regression cases failed before the fixes. No Required findings remain.

Verification combines 13/13 focused source tests, the independent full native
journey passing 1/1 on `bcf1c3f`, and the final changed sidebar raw accessibility
assertions passing on `4c751867`. The later full repeat expired at a controller
checkpoint and did not finalize its result bundle; it is not a full-method pass.
A CUA termination race launched plain fresh-product PID 14029; it was stopped
immediately and exit verified. Incidental effects are not established. The
canonical evidence records this limitation and retained scratch; no repair or
cleanup is authorized. Unchanged properties retain their earlier terminal checks.

Phase 6C architecture consultation `01a08d16-cc19-7143-b158-f175f88ef1a6`
(Astra High) is complete, quiescent and archived, with no blocking owner choice. Its bounded
recommendations are preserved in the
[6C brief](../task-briefs/2026-09-10-phase6c-evidence/phase6c-evidence-brief.md): explicit
recorded target, immutable observations, exact applicability, typed replay and
existing removal/backup recovery extensions. This is consultation, not candidate
review. Writer `01a08d1c-cecc-7670-817a-7c5a1e3f3d69` (initial Sol High,
bounded Astra High escalation) completed source and native evidence in worktree
`df09`. Initial candidate `9baf37b92dab2756c1d31fe05cb313d3ce837463` and correction
`a5dac63970d9d02ff76adac7f3d4bcd5423706b1` are integrated at
`2335873892299310a811cb2b8cb0d8a139d10ef6`. The final native evidence passed 1/1;
root verified the visible compact panel and Help, and the independent reviewer
reported no visual findings. Four Required applicability/provenance findings were
corrected with 17/17 affected tests passing. The same independent Astra High
reviewer `01a08d84-9063-7af2-bfb6-bd4c23328d8b` approved that bounded delta with
no remaining findings. Phase 6C is complete locally. Writer and reviewer are
quiescent and archived, their commits and evidence preserved, and their build/test
reservation is released. Reviewed local endpoint is `codex/phase6c-reviewed`. Evidence and retained scratch are described in the
[canonical record](../evidence/2026-09-10-phase6c-evidence.md).

Read-only chief consultation `01a08d93-8aa5-7611-a33e-e8fdb960d52c`
(Astra High) completed its assessment with no blocking owner choice. Its
recommendations are preserved in the
[6D brief](../task-briefs/2026-09-10-phase6d-adoption/phase6d-adoption-brief.md): complete
scoped inventory, guidance-driven exact approval/replay, existing task commands
and native readback, 6C applicability and compatible guidance v3. This is a
consultation, not independent candidate review; the chief task is archived.
The catalogued brief was committed at `0265a102ccf06b7507f279896399860b6e3a05e7`
before fresh Sol High writer `01a08d97-f771-7de2-9384-e58d69a9178f` was dispatched
from that baseline. It owns source/tests/affected docs; root owns this ledger and
catalog/index metadata. Ceiling Astra High, no subagents. Actual requested model
and effort were set at dispatch; runtime settings are not independently exposed.
Phase 6D is complete locally. Initial candidate
`0cd0a193e81d46264f1730ca0c5356504595898c` and correction
`4f3a78ac8fba2d63401f1801f970282d1091f3f0` are integrated at
`1f4f5ed45cdf0e04b2e4bec7251c0081a5c9fbcd`. Direct evidence includes 4/4 adoption
acceptance, focused guidance/package compatibility, final guarded native 1/1,
and 9/9 affected correction tests. Root verified the compact Tasks/Help in the
exact isolated host, stopped CUA before completion and confirmed host exit.
The [canonical evidence](../evidence/2026-09-10-phase6d-adoption.md) and four images
are catalogued. Independent Astra High reviewer
`01a08dd9-47dd-7ea0-b208-810fe7514e32` approved all three bounded corrections:
separate catalog/guidance version labels, pre-implementation approved-catalog
instructions and durable reconciliation/replay recording. No Required findings
remain. Writer and reviewer are quiescent and archived; all reservations are released.
Reviewed local endpoint is `1d69858f98f55af1ef504f4a43df1c601db879b9` on
`codex/phase6d-reviewed`.

Read-only 6E chief consultation `01a08dab-7ac7-7031-96c8-d658e29bfe1e` (Astra High)
is complete and archived with no blocking owner choice. Its bounded search identity,
SQLite-backed saved preference, recovery and shared Help recommendations are
preserved in the [6E brief](../task-briefs/2026-09-10-phase6e-search/phase6e-search-brief.md).
Reviewed 6D integration is complete. Fresh Sol High delivery task
`01a08dee-d569-7350-af9f-0a89274103f0` is dispatched from exact handoff
`ded1dbee9fc53d533a2ac3364c235eca560ccccb`. It is the sole product writer for
Search, saved views and Help; root retains ledger/catalog/index ownership.
The profile addresses cross-component identity, persistence and recovery;
ceiling Astra High, no subagents, never Ultra. Actual requested settings were
set at dispatch; independent runtime settings readback is unavailable.
The writer synchronized merged default `f0c9e42af4a5eb19d739979e7dfa33239a8e4a3a`
through ordinary merge `a8c23789d7477638c34eade33c76028c2bd8d448`, preserving
its uncommitted work without conflicts. Initial core search acceptance passed
1/1 with zero failures/skips, directly read back from the isolated result bundle.
Candidate `e7c92a25b61ce444b57b60a3a9e73159494b9398` is integrated locally.
Direct checks combine five initial Search/Help passes, the corrected retired-ticket
case 1/1, route/recovery 4/4, navigation/native rendering 2/2 and the isolated live
native journey 1/1. Root verified the exact host, Search/save/navigation/Help and
compact scrolling, stopped CUA before completion, and confirmed host exit.
The [canonical evidence](../evidence/2026-09-10-phase6e-search.md) and three PNGs
are catalogued; the repository documentation check passes. Fresh independent
Astra High reviewer `01a08e2f-2be2-78d1-8bc0-ec72f17bc17d` requested eight
Required corrections: unsupported-query preservation, deliberate restored-scope
reauthorization, nullable decision metadata, exact destination filters, stale
asynchronous results, byte-exact scope identity, shared Help completeness and
audit/reference ID matching. The same writer is correcting this bounded outcome,
with explicit Astra High escalation for authority/recovery and byte identity;
Correction `8056ae7e4063f3171d0410f87453c0b4adc9cad1` is integrated at
`98b9671d4c84ae9a7977b14304dbccd04c93d310`; direct checks passed 10/10
regressions, 8/8 affected integration cases and 1/1 focused native controls.
Root verified corrected Help with real keyboard input in the isolated host.
The same reviewer resolved seven findings and ordinary-edit invalidation; only
the original R5 recovery-clearing invalidation boundary remains. The writer is
making that bounded correction with one focused regression. Reviewer is
quiescent and archived pending that same-outcome correction. Phase 6E is not complete.
No shared build/native slot is held.

## Authorization and next eligible work

The complete Phase 6 outcome remains History/attention, distinct workspace
Delivery and Execution Goals, revision-bound evidence, generic task adoption,
workspace search/saved views and contextual Help. Current source slice is
6E workspace search, saved views and Help under its committed brief.
Owner explicitly authorized pushing reviewed 6A/6B and opening separate PRs.
Publication state:

- [PR #44](https://github.com/joeroberts/release-radar/pull/44):
  MERGED, head `da52b47ada7ec3d1b5966adf956d48e5268ee00b`,
  base `codex/release-radar-mvp`, merge `4f917b0c76fa74ebf4e0f4615cbf7e7dd4ac8597`.
- [PR #45](https://github.com/joeroberts/release-radar/pull/45):
  MERGED at 00:42 UTC September 11, head
  `c7c36425dbee669bedbbb3f3ce328a91853d5d8c`, base `codex/release-radar-mvp`,
  merge `1e03d9ad8a36c7c7ec80525233df6a5e7c3217e8`; follows merged #44.

The coordination branch remains local; reviewed 6C/6D publication branches are now pushed separately. PR #44's Required reset correction passed direct tests and independent review.
The other four bot suggestions were assessed as non-blocking; event-time unknown
provenance, existing failure recovery and direct migration checks are preserved.
Root completed the owner-requested CodeRabbit review on #45 after #44 merged.
Actual review `5173582848` completed at 00:12 UTC September 11. The four valid
findings—Goals state reset, filtered focus recovery, missing-board execution
links and same-focus viewport restoration—were corrected, directly tested and
approved by the same independent reviewer. The SQL terminator report was absent
from the actual source; the optional lane assertion was hardened. Root pushed
the reviewed correction, merged #45 and verified the GitHub result, then integrated
the merge locally. No 6C/6D implementation was included in publication.
Local source/tests/affected docs, scoped commits and necessary
fresh bounded peer tasks are authorized. One product writer at a time; the
orchestrator does not implement product or use subagents. Exact committed baselines
and independent risk-appropriate review remain required.

Issue #1 includes minimum product-owned generated guidance/packaged skill source
and focused audited-handoff/compatibility tests. ADR-006 reserves guidance v3;
preserve immutable shared-V1 version/digest pairs. No governing AGENTS, installed
skills/config, consumer instructions or guardrails may change.

Owner subsequently authorized 6D push/PR and actual CodeRabbit review with scoped
valid feedback corrections. The required 6C dependency is published separately:

- [PR #46](https://github.com/joeroberts/release-radar/pull/46): 6C prerequisite,
  MERGED at 01:05:27 UTC September 11, head
  `c1ee62f0e31e82337e02d06d898d152a18de723e`, base `codex/release-radar-mvp`,
  merge `fbb0ab5da811ad0db51f1441492aa8c5531e3ce3`.
- [PR #47](https://github.com/joeroberts/release-radar/pull/47): 6D adoption,
  MERGED at 01:05:39 UTC September 11, head
  `e9bf7801594386900e4afacb37cbde220429f7be`, retargeted base
  `codex/release-radar-mvp`, merge `f0c9e42af4a5eb19d739979e7dfa33239a8e4a3a`.

Both publication branches were synchronized by ordinary merges, their scoped
diffs and documentation checks verified, and actual CodeRabbit reviews requested.
The owner subsequently explicitly waived the pending/rate-limited CodeRabbit
wait and authorized immediate merges using completed independent reviews and
direct checks. No actual bot review or inline finding had returned at merge;
this is not a claim that CodeRabbit approved. Root merged #46, retargeted #47
with its scoped delta unchanged, merged #47 and verified both GitHub results.
The current default was fetched and integrated locally without tree changes.
Root remains the sole integration/correction coordinator.
Installation still requires separate approval. The owner briefly paused 6E for publication
then explicitly reversed that pause: 6E continues from its assigned reviewed
baseline and preserved test. It does not wait for publication or merge; later
upstream synchronization must preserve its work. Installation/other-Mac owner testing wait until
September 11 or later and do not block authorized source work. No owner
state/SQLite, credentials, catalog binding/acceptance, consumer adoption,
notifications, external security scans, runtime/hooks, packaging or cleanup.

## Verification and retained limitations

Direct xcresult readback confirms initial focused 20/20, affected correction 10/10,
and final R4 native 1/1 with zero failures/skips. The two R4 model tests passed in
the prior three-selector run; its sole failure was an invalid directional offset
assertion, removed in the final test-only correction. Final independent native
review verified actual wide non-edge and compact bottom viewport restoration,
full inspector and visible focused Open. Six other correction reviews are terminal.
A broader Task 11A readiness-prerequisite failure remains separately reported;
no full-suite green or installed acceptance claim. Repository documentation and
scoped diff checks pass; application state is not inferred from local checks.

During writer R4 verification, unauthorized unsanitized/signed and direct-xctest
attempts breached the required test isolation. Writer launches were revoked and
its products excluded. Service/Keychain effects are not established. The final
reviewer used fresh unsigned products, explicit sanitized `env -i`, a clean copied
pinned dependency cache, and the established inert synthetic XCTest startup. Its
verified hosts exited. Future native checks require a serialized reservation,
that same sanitized unsigned startup, unique results/session markers and verified
host PID/window before CUA. No signed/direct-xctest/linker fallback or plain owner
app launch is authorized. The incident does not authorize repair or cleanup.

Application inventory/binding/acceptance/readback remain unauthorized. Last
canonical inventory was `bindingMissing`, `isComplete:false` for
`project-fffdc0e0b15b9b86`; no managed-current or synchronization claim is made.
All durable 6A artifacts are repository-canonical. Retained temporary output is
listed in the canonical evidence, including writer roots and reviewer roots
`/private/tmp/release-radar-phase6a-review-01a08c37.09_u6p48` and
`/private/tmp/release-radar-phase6a-r4-review-01a08c37.MJLXYm`. Existing PNGs are
accurately labelled initial native screenshots, not immediate after-Back captures.
All scratch, including contaminated products/symlinks, remains; no cleanup occurred.

An empty incidental scratch file `/tmp/phase6b-unused` was created during
coordination and is temporary; it remains retained with no cleanup authorization.

Temporary PR body files remain in `/tmp/release-radar-phase6-publication/`
(`phase6a-pr.md`, `phase6b-pr.md`); the published PR descriptions are canonical.
No cleanup authorization was requested or granted during publication.

## Phase 6C candidate review

Writer candidate `9baf37b92dab2756c1d31fe05cb313d3ce837463` is integrated locally
with [canonical evidence](../evidence/2026-09-10-phase6c-evidence.md) and inspected
wide/compact native screenshots. The writer's initially reported full hash did
not resolve; direct Git readback established the candidate above. Source is
frozen, writer quiescent and reservation released. Direct result readback confirms
integrated native route/Help test 1/1, zero failures/skips; root controlled only
verified PID 30450/tokenized window, stopped CUA, then wrote completion before
host exit. Final compact capture visibly contains the panel. Prior focused
acceptance, applicability, recovery and transport evidence is recorded canonically.
Independent reviewer `01a08d84-9063-7af2-bfb6-bd4c23328d8b` (Astra High)
returned four Required corrections: withdraw superseded evidence from current
assessment, app-owned recording time/order, unknown checkout applicability, and
consistent PR head/merge revision identity. Same writer is correcting these under
the existing scope; reviewer is quiescent awaiting the affected delta. Native
visual/Help evidence is accepted and terminal. No 6C source or coordination branch
is published.

Owner additionally requires an actual CodeRabbit review on PR #45 after #44 is
merged and #45 retargeted to `codex/release-radar-mvp`. Root is authorized to post
`@coderabbitai review`, assess findings, fix Required defects with affected checks,
and merge #45 afterward. A skipped success status is not that requested review.

## September 12 release and integration checkpoints

Historical and non-authoritative. The following ledger snapshot was retained from
`d6f123a` during the owner-approved PR #54 reconciliation. Its present-tense
statuses, prior publication restrictions, branch names and pending task references
describe earlier checkpoints, not current authorization or outstanding work.
Current delivery state and the remaining acceptance limits live in
[progress](../progress.md). Relative evidence links have been rebased; the recorded
results and limitations are preserved.

# Release Radar delivery state

## Current outcome

Releases 0.1.14–0.1.16 are merged into the default branch through
[PR #52](https://github.com/joeroberts/release-radar/pull/52), preserving the
existing commit order. Tags `v0.1.14`, `v0.1.15` and `v0.1.16` are published
unchanged. The saved project checkout is synchronized with the merge, and the
unassigned `release_radar-phase6-design-review` worktree and its build output
have been removed. The unauthorized saved-checkout rule was withdrawn at the
owner's request. Prior DMGs and unrelated files remain preserved. No rebuild or
installation was needed for this reconciliation.

The owner-authorized **RDS search-submit focus correction** is complete and
installed locally as **0.1.16 (1)**. Release Radar now pins merged
RekonDesignSystem revision `f986e85e786f55f1d73d6e429de11370399414f7`.
The toolbar retains its borderless bookmark Save control immediately right of
the search field in the centered micro-spaced group at wide and compact widths.
The consumer's independent code/UX review identified stale-evidence and
focused-submit proof gaps; both were corrected without an additional review
cycle. Focused inert-host checks and the [0.1.16 package evidence](../evidence/2026-09-12-release-0.1.16-packaging.md)
record the resulting layout, focus, clear, accessibility, signature, installer
and smoke-launch results. No owner search preference, SQLite state, remote, PR,
notarization, or publication action occurred.
The completed RDS and consumer correction tasks are idle and archived. Their
results are preserved in their repositories; local annotated `v0.1.16` targets
`76cce40`. Release Radar remote integration is complete through PR #52.
Phase 7 tasks remain untouched.

The owner resumed **Correct Add Project RDS styling** to close its missing review.
Candidate `8176e319` incorporates the merged default baseline and applies existing
RDS window chrome and Cancel/Initialize/Attach styles. Both focused AppRoute tests
passed. One independent code/UX review approved the candidate with no findings.
Full native-window captures are preserved at [default size](../evidence/2026-09-12-add-project-rds-window-default.png)
and [minimum size](../evidence/2026-09-12-add-project-rds-window-minimum.png); the inert
fixture shows inactive traffic lights and does not launch the installed owner app.
The reviewed candidate and its integration record `3d6a98d` are packaged locally
as **0.1.14 (1)**. The signed DMG, matching Downloads copy and installed app are
recorded in the [0.1.14 package evidence](../evidence/2026-09-12-release-0.1.14-packaging.md).
No push, PR, default-branch merge, notarization or owner-data mutation occurred.
The completed, idle Add Project task is now archived at the owner's request.
Its release commits and evidence are preserved in the canonical integration
checkout; this master task retains the pending remote integration endpoint.

The owner subsequently reopened the same correction after the installed 0.1.14
Initialize screen exposed unstyled later-workflow controls. The local candidate
`39ca6bc` extends existing RDS controls across Initialize and Attach selections,
confirmations, completion and error states; it preserves folder-picker and data
behavior. Fresh native-window captures and the independent re-review are recorded
in the [later-workflow evidence](../evidence/2026-09-12-add-project-rds-later-workflows.md).
The correction is packaged and installed locally as **0.1.15 (1)**. Its signed
DMG, matching Downloads copy and installed identity are recorded in the
[0.1.15 package evidence](../evidence/2026-09-12-release-0.1.15-packaging.md).
The corrected delivery task is complete, idle and archived again. Local release
tag `v0.1.15` identifies package commit `94a7768`; remote integration of the
0.1.14/0.1.15 changes subsequently completed through PR #52.

The owner also reported an unexpected `TEST` search value and a blue square
around the search-submit icon. Read-only diagnosis against installed 0.1.14
found `TEST` in the sandbox store's supported working-search preference, saved
at 2026-09-12T16:17:36Z with the generic `release-radar` audit actor. Startup
restores that value; the code default is empty. The record does not identify
the initiator, so attribution remains unknown. The submit button has a separate
focus state inside pinned RDS `RekonSearchField`, consistent with the native blue
focus treatment in the screenshot; exact focus transitions were not exercised.
No search preferences were changed. The owner subsequently authorized correction
of the blue submit-button focus treatment. The original RDS toolbar delivery task
is reopened for that bounded correction, with native focus/keyboard verification,
one independent code/UX review and the authorized RDS PR/merge workflow. Release
Radar will adopt the verified library merge and follow its standing local release
workflow. Saved search data and search-persistence policy are outside this fix;
the focus correction is not part of 0.1.15.
The read-only toolbar diagnosis task is complete and archived with this result
preserved here.

The owner authorized immediate reconciliation of delivered local releases with the
actual default branch, `codex/release-radar-mvp`, on September 12. The dependency
chain is preserved through [PR #50](https://github.com/joeroberts/release-radar/pull/50)
(acceptance, helper, navigation and RDS-field prerequisites),
[PR #49](https://github.com/joeroberts/release-radar/pull/49) (toolbar adoption), and
[PR #51](https://github.com/joeroberts/release-radar/pull/51) (remaining 0.1.12/0.1.13
changes and release records). All three PRs are merged into the default branch;
the final integration merge is `8de63b16e2fa0f84ca79b4c691e4a43117befce2`.
The separately recorded 0.1.11 installation closeout is retained in that history.
Both local integration and saved-project checkouts were synchronized with origin
at that reconciliation checkpoint.
The completed **Fix Search fields to use RDS** and **Phase 6 DMG and manual
acceptance testing** tasks are archived after their commits reached the default
branch and their work stopped. A subsequent owner correction exposed an incomplete
task-list result: local records contained 14 top-level Release Radar tasks, while
the listing tool returned only two. Direct reads identified eight more completed
and quiescent tasks: three Phase 6 design reviewers, the 0.1.10 and 0.1.11 package
tasks, the Restart helper package task, and two Phase 6 acceptance reviewers.
Their results were verified in merged history and those eight tasks are archived.
The owner subsequently archived the completed missing-Pursuit-phase diagnosis
and the stopped metric-layout task. The recovery design remains sequenced after
Phase 6H; metrics remain stopped under Phase 6F. After the Add Project archival,
the remaining tasks from this cleanup inventory are:

- Master Delivery Thread — orchestration.
- Phase 7 portable continuity plan — replacement — preserved at owner request.
- Phase 7 portable continuity independent… — preserved at owner request.

Only the Add Project task was resumed. Phase 7 tasks were not changed.

The installed release is **0.1.15 (1)**. Its local annotated `v0.1.15` tag targets
the package-record commit; published tags `v0.1.10` through `v0.1.13` retain their
original release commits. The installed app version and matching repository/Downloads
DMG checksum were read back after packaging. The [0.1.15 package evidence](../evidence/2026-09-12-release-0.1.15-packaging.md)
records identity, direct package checks and verified installation. Existing DMGs
remain rollback copies; no extra app backup is needed.

Fresh combined-source verification selected 207 tests: **194 passed, 7 skipped,
and 6 failed cases (12 assertions)**. All six failed identically on unchanged
default commit `5e7b9b8`: four native fixtures could not write outside the sandbox,
one native board test could not obtain its AX element, and the native phase
lifecycle journey retained its prior lifecycle/revision assertion failures. These
are pre-existing failures, not a green full suite. Navigation/history, Search,
Help, planning policy, helper restart and the new toolbar checks passed.
Documentation catalog/index and diff checks pass. Existing independent product
reviews remain terminal; no redundant package review was added.

Only repository integration and the requested completed-task cleanup are included.
Phase 7 stays paused and its tasks remain untouched. The missing Pursuit phases
diagnosis is archived with its recovery design preserved; unimplemented Phase 6 extensions and the Phase 8
isolated stale-helper test retain their recorded boundaries. Repository integration
does not claim application catalog acceptance or mutate owner project data.

The milestone records below preserve their original scope and verification; their
local-only publication restrictions are superseded only for this authorized
integration. The active endpoint above controls current release status.

The original Phase 6A–6E sequence reached the default branch at
`5e7b9b86e55cd8aed192fb116bbe0bcae9bea66a`, before the corrective integration above. The delivered scope follows the
[Phase 6 controlling plan](../plans/2026-09-10-phase6-outcomes-tasks-history.md):
History and attention, distinct Delivery and Execution Goals, revision-bound
evidence, generic task adoption, workspace Search, saved views, and shared Help.

| Slice | Merged endpoint | Canonical evidence |
| --- | --- | --- |
| 6A History | [PR #44](https://github.com/joeroberts/release-radar/pull/44), merge `4f917b0c76fa74ebf4e0f4615cbf7e7dd4ac8597` | [6A evidence](../evidence/2026-09-10-phase6a-history.md) |
| 6B Goals | [PR #45](https://github.com/joeroberts/release-radar/pull/45), merge `1e03d9ad8a36c7c7ec80525233df6a5e7c3217e8` | [6B evidence](../evidence/2026-09-10-phase6b-goals.md) |
| 6C Evidence | [PR #46](https://github.com/joeroberts/release-radar/pull/46), merge `fbb0ab5da811ad0db51f1441492aa8c5531e3ce3` | [6C evidence](../evidence/2026-09-10-phase6c-evidence.md) |
| 6D Adoption | [PR #47](https://github.com/joeroberts/release-radar/pull/47), merge `f0c9e42af4a5eb19d739979e7dfa33239a8e4a3a` | [6D evidence](../evidence/2026-09-10-phase6d-adoption.md) |
| 6E Search and Help | [PR #48](https://github.com/joeroberts/release-radar/pull/48), merge `5e7b9b86e55cd8aed192fb116bbe0bcae9bea66a` | [6E evidence](../evidence/2026-09-10-phase6e-search.md) |

The [Historical Phase 6 record](2026-09-11-phase6-delivery-history.md)
preserves closed checkpoints, review history, and earlier task identities.

## Owner correction candidate — September 12

The owner directed two focused corrections to the toolbar/help adoption: Save query is
again a borderless bookmark icon immediately beside the central Search field at wide
and compact widths, and Help groups its existing guidance as Projects, Settings and
Goals. Each help destination remains in-app and is exposed by a borderless up-right
arrow beside its title with its meaningful accessible Open name. Focused unit and
native rendering checks pass; the durable captures are [wide toolbar](../evidence/2026-09-12-toolbar-bookmark-wide.png),
[compact toolbar](../evidence/2026-09-12-toolbar-bookmark-compact.png), and
[grouped Help](../evidence/2026-09-12-help-topic-groups-wide.png). Independent code/
UX review approved commit `c045f29` with no Required or Optional findings. Its
focused check passed 8 tests; 3 broader native Search/Help cases remained skipped
because the XCTest host exposes no self-AX window after focus, not because of a
candidate failure. The local-only endpoint is complete; catalog acceptance and
application readback are not authorized by this UI correction. No packaging,
installation, push, PR, merge, owner data, live app state, RDS-library, version,
tag, metric, project management, archive/remove, or guided-setup work is included.

## Completed local RDS toolbar consumer adoption — September 12

The owner authorized Release Radar to adopt the merged RDS toolbar/search controls
at `3c2626102a2e97dd93f31fbc62b733085d6700ec`. The bounded implementation is complete locally
on `codex/rds-toolbar-adoption` from assigned baseline `83f3bb8`, controlled by the
[toolbar adoption brief](../task-briefs/2026-09-12-rds-toolbar-adoption/rds-toolbar-adoption-brief.md)
and the [approved proposal](../../design/phase6-workspace-toolbar-proposal.md). The
assigned baseline is available locally but its named design branch is not
advertised by `origin`; this does not replace or discard the assigned commit.

Scope is the persistent RDS toolbar, app-owned draft/submission/save/history flow,
compact and wide sidebar adoption, fixed documentation-checking footer, relevant
guidance, focused tests and isolated native render evidence. Phase 6F metrics,
Manage Project and Archive/Remove relocation, guided setup, packaging,
installation, merge and owner/live application state remain separate and
unauthorized. Independent code/integration and UX/accessibility review is complete.
The delivery and review tasks are archived with their processes stopped. The
reviewed result and captures are preserved in the canonical project checkout;
monitoring is paused. The owner subsequently authorized reconciliation of delivered work.
[PR #50](https://github.com/joeroberts/release-radar/pull/50) landed the prerequisite
baseline, and [PR #49](https://github.com/joeroberts/release-radar/pull/49) was
retargeted and merged into `codex/release-radar-mvp`. Later release records below
cover packaging and installation.

The initial local candidate `42e40f3` entered independent review. The reviewer
found one required save-failure recovery defect: a failed save from a non-Search
route could be silent, and an existing same-named query could incorrectly dismiss
the popover. The bounded correction now returns the exact save-attempt outcome,
dismisses only on confirmed success, and retains the entered name with an
accessible actionable error on failure. Corrected candidate `8cd2bc6` passed
follow-up independent review with no Required or Optional findings. The author’s
five affected tests and the reviewer’s four directly affected tests pass,
including the non-Search same-name regression, successful save path, native
accessible failure presentation and wide/compact toolbar accessibility. The app
build, documentation check and diff check pass, and both exact-candidate
worktrees are clean.

Before that correction, the focused XCTest selection passed 40 tests with 3
explicit skips caused by the XCTest host exposing no self-accessibility windows
after Search took focus; the toolbar test itself asserts every action is fully
visible and accessible at 1280 and 760 points. All 9 workspace-search acceptance
tests also pass.
The disposable native test app was also exercised through supported external UI
inspection: Return submission, Back restoration, save-without-run, Escape
dismissal, and wide/compact accessibility all passed. The app build and managed
documentation check pass. The reviewer did not independently repeat the external
Return/save/Escape fixture because its sandbox could not remove the fixture’s
hard-coded `/private/tmp` enable sentinel; the author evidence remains reported,
and the disposable sentinel is now absent. Review captures are the
[wide toolbar](../evidence/2026-09-12-rds-toolbar-wide.png) and
[compact toolbar](../evidence/2026-09-12-rds-toolbar-compact.png). No installed app,
owner database or live application state was changed.

## Phase 6 extension design review — September 12

The owner requests separate feature-architecture, chief-architecture and UX reviews
of the [toolbar and project-management proposal](../../design/phase6-workspace-toolbar-proposal.md)
and its linked static mockup. Requirements include persistent search/navigation,
RDS reuse, Manage Project relocation, guided shared-execution setup and metric
alignment. These are required Phase 6 scope, not implementation authorization.
Metric implementation was explicitly stopped and remains stopped. The proposal
preserves the owner's 6F/6G/6H assignments and flags the earlier guided-setup naming
for reconciliation. No app state or catalog acceptance is changed by this review.

All three reviews and their requested options have concluded. The owner accepted
the wide and corrected compact mockups as visual references and selected toolbar
search with results-page filters/saved queries, the compact icon sidebar with
direct Help/Settings/Notifications and bookmark Save, immediate Manage Project
loading with in-place recovery, and Codex-task-mediated guided setup. The proposal
records those selections. RDS API details and the guided-setup slice label remain
proposed; product implementation has not been released.

The separate RekonUI Library versioning/toolbar prerequisite has now passed its
independent review with no remaining findings. Its plan is recorded on
`codex/rds-versioning-toolbar-plan` in
`docs/delivery/plans/2026-09-12-rds-versioning-toolbar-plan.md`; RDS closeout commit
`09dd3a8` records the final disposition and passing canonical documentation check.
The existing missing historical catalog artifact was restored unchanged. Both
bounded RDS planning/review tasks are stopped and archived; monitoring is paused.
The owner subsequently approved RDS toolbar/search implementation. It is merged via
[Add reusable toolbar and search controls](https://github.com/joeroberts/RekonDesignSystem/pull/7)
at `3c2626102a2e97dd93f31fbc62b733085d6700ec`. GitHub confirms MERGED and CodeRabbit
SUCCESS. Independent API/code/UX review had no findings; 97 package tests, 13 focused
tests and 2 public-API tests passed. Author native wide/compact checks passed; the
reviewer independently exercised the wide fixture and inspected compact layout,
without a new independent compact capture. RDS supplies `RekonToolbar`,
`RekonBorderlessIconButtonStyle` and additive `RekonSearchField` prompt/submit support.
The implementation/review processes stopped, results are in the merged RDS ledger,
and both bounded tasks are archived. Monitoring is paused. Historical/new tags and
Release Radar consumer adoption remain separate actions. No tags, consumer change,
installation or owner-state mutation occurred.

## Pursuit plan reconstruction — design only

The owner approved the [one-time reconstruction decisions and entry reference](../../design/repository-plan-reconstruction-design.md)
and delegated durable persistence, review and sequencing to Master Delivery Thread.
The package is recorded with its approved mockup and catalog identities; independent
architecture/security-recovery/UX design review passed with no findings. Documentation
and diff checks pass. The review is complete and its task archived. Implementation follows
the final currently planned Phase 6 extension through 6H, not merged 6E. The
separately proposed guided-setup 6I label is not an added dependency by inference.
Reconstruction uses only a supported versioned structured snapshot, preserves
explicit current lanes, and never fabricates historical activity. Atomic approved
application remains provisional on a usable blocker-resolution/exclusion journey.
No implementation, live recovery, database write, installation or publication is
authorized. Source schema and exact execution/recovery contracts remain to resolve
before implementation; no current snapshot is declared import-ready.

## Release 0.1.11 package details

The reviewed RDS treatment for the main Search input, saved-query name input and
Help search input is packaged as Release Radar `0.1.11 (1)`. Version/source commit
`fbf93e515a5dac4d35c54f463dee3692d7486de8` adds the matching app and bundled
plugin versions and exact recognized plugin digest on branch
`codex/release-0.1.11`. The annotated local tag `v0.1.11` identifies the containing
release commit.

- DMG: `dist/ReleaseRadar-0.1.11.dmg`
- Durable owner copy: `/Users/jroberts/Downloads/ReleaseRadar-0.1.11.dmg`
- DMG SHA-256: `06891ba3fdfc3730bcb3348c45255c474b53cac348f68ceedfbb03c16adb62f2`
- Main executable SHA-256: `a093bbdccff161ecbbc46d74adbb3b518e8ad45233288e8bc0271f63a6a9ab9a`
- CodeResources SHA-256: `dee39d94d9ba1e0ccd7a4f6181dd0d29099fa9d44acd23aa68af7cb1e41da7bf`
- CodeDirectory hash: `85cef76aef01baae60d9b1e1a5606b1943c5ec00`
- Plugin digest: `2677797fd17f0091821cca09653f9951ab9007ef578a1226458faf632d319a9d`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The [0.1.11 packaging evidence](../evidence/2026-09-12-release-0.1.11-packaging.md)
records the previously completed 12/12 correction checks and independent code-and-UX
approval, focused version/resource verification, strict signed staging, read-only
DMG mounting, staged/mounted identity and the matching Downloads copy. Under later
explicit owner authorization, that exact package was installed in place after the
signed `0.1.10 (1)` app was preserved at
`/Users/jroberts/Documents/Release Radar Backups/Pre-0.1.11-2026-09-12.ReleaseRadarAppOnly.Xekm4B/ReleaseRadar.app`.
The installed `0.1.11 (1)` bundle matches the package's executable,
`CodeResources` and CodeDirectory hashes. It launched normally from `/Applications`;
ordinary startup registered fresh lifecycle and Bridge processes from the new
bundle, and both pass strict signature checks. No manual plugin/configuration
change, direct owner-data operation, catalog acceptance, push, PR, merge or
publication occurred. The package remains locally signed and not notarized.

## Release 0.1.12 package details

The independently reviewed RDS toolbar candidate is packaged as Release Radar
`0.1.12 (1)` from version/source commit
`0a281c1e812725d979ffccfd57782695aca4bef4`, which contains product candidate
`8cd2bc634b8c06d04ec59e00e477ebc32f308192`. The bundled plugin is `0.1.12`
with recognized digest
`8f23498996d2beb1994db711d39527ef42a96ffab6344d1976e5e18f925e90eb` and
the RDS dependency remains pinned to
`3c2626102a2e97dd93f31fbc62b733085d6700ec`. The annotated local `v0.1.12`
tag identifies the containing release-record commit.

- DMG: `dist/ReleaseRadar-0.1.12.dmg`
- Durable owner copy: `/Users/jroberts/Downloads/ReleaseRadar-0.1.12.dmg`
- DMG SHA-256: `740da6bdb097207c26de686e22a8c0b9bac0abb6940935374a8826dd91232261`

The [0.1.12 packaging evidence](../evidence/2026-09-12-release-0.1.12-packaging.md)
records focused version checks, signed no-launch staging, read-only mounted image
verification, strict nested-code and entitlement checks, and identical staged/mounted
hashes. The installed app remained running and unmodified. No app launch,
installation, SQLite/Keychain access, notarization, push, PR, merge or publication
occurred; this is not a generally distributable notarized release.

## Active navigation responsiveness correction

The owner authorized a bounded correction for project-navigation clicks that
appeared inert while Release Radar awaited the dashboard-open audit and a full
documentation observation. The local `codex/navigation-responsive-validation`
candidate is based on the verified Phase 8 documentation baseline
`c2962d9374306a7db0a36985aba1a681fd48177c`; source and tests are committed at
`43b4617`, with the navigation-specific failure-state correction at `140487d`.

Overview, Project Plan and Phase Board now publish their selected route, focus and
history entry before awaiting the existing audit and read-only documentation
validation. Validation still withdraws stale evidence while checking, so existing
evidence-dependent action guards remain fail-closed. Rapid navigation retains the
latest requested destination, and a dashboard-open failure appears in an
actionable inline banner without replacing that destination. The project sidebar
shows a native animated progress indicator with accessible **Checking project
documentation** text while validation is pending. No polling interval, persistence
schema, data-loading architecture, authorization rule or external integration was
changed.

Direct verification currently passes 62 tests with 2 signed native-picker tests
skipped and no failures across navigation history, documentation observation,
native wide/compact rendering, Help and the first-dashboard-open notification
boundary. The new status was visually inspected at 280- and 86-point widths
against the approved Phase Board sidebar language. Independent reviewer task
`01a0937b-4d46-7c30-8292-663c1e5de0bc` approved the exact candidate through
`1da1427b336ca2c89f18c7f155da6aeef6fe9703` with no Required or Optional
findings; its independent focused selection passed 7 of 7 tests. The bounded local
implementation and review endpoint is complete. The later package authorization
covered the scoped 0.1.10 version metadata, signed local DMG, release evidence,
local commits and annotated local version tag only.

The installed `0.1.10` build now has bounded owner manual acceptance for the
reported responsiveness defect. The owner's screenshot showed Pursuit Overview
loaded with documentation and catalog status current; the owner confirmed that
Overview, Project Plan, Phase Board, and the Pursuit project-card route to Overview
all opened promptly, and that the loading animation appeared while validation ran.
Rapid switching and latest-destination retention, fault injection, the complete
Phase 6 owner guide, and the Phase 8 stale-helper scenario were not explicitly
confirmed and remain outstanding.

The Phase 8 stale production-helper acceptance scenario remains deferred and
unchanged.

## Release 0.1.10 package candidate

The reviewed responsive-navigation and loading-animation correction is packaged
as Release Radar `0.1.10 (1)`. Version/source commit
`130e90846cd59ed3a181cf3665bbd27cd50d03cd` adds the matching app and bundled
plugin versions and the exact recognized plugin digest while preserving earlier
recognized identities. The annotated local tag `v0.1.10` identifies the containing
release commit.

- DMG: `dist/ReleaseRadar-0.1.10.dmg`
- Durable owner copy: `/Users/jroberts/Downloads/ReleaseRadar-0.1.10.dmg`
- DMG SHA-256: `a28ee8e47c92fc7256f274448ffc3083a442a09b8eee4a70c89e06ed67d4617b`
- Main executable SHA-256: `1493df3303c00e78ae9affb8aef44e9d2d7cf705a09034a2c2530a342396057e`
- CodeResources SHA-256: `e246a98214fc7f60eb04cf93c05249e5f8ba14ed3188648b3e72e30fafdca606`
- CodeDirectory hash: `d6c7a7dbbfa4fef6934cb8709f2b7e2f38581619`
- Plugin digest: `7f70bcd7a4fac4fe038dc00945b8fb56d3cdd472ec7f7816c40812631107939c`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The [0.1.10 packaging evidence](../evidence/2026-09-11-release-0.1.10-packaging.md)
records focused version tests, strict nested-code and entitlement checks, read-only
DMG mounting, staged/mounted identity and the matching Downloads copy. Under later
explicit owner authorization, the verified Downloads DMG was installed in place.
The prior `0.1.9 (1)` application remains available at
`/Users/jroberts/Documents/Release Radar Backups/Pre-0.1.10-2026-09-11.ReleaseRadarAppOnly.V5Ojxa/ReleaseRadar.app`.
The installed application is now `0.1.10 (1)`, matches the package's signed
executable, `CodeResources`, and CodeDirectory identity, and reopened the existing
Pursuit workspace. Normal startup replaced both service processes with executables
from the new `/Applications/ReleaseRadar.app` and reported the Codex plugin as
**Installed** at `0.1.10`; no manual plugin or helper action was used. The local tag
remains on the original release commit. This package is not notarized or generally
distributable. Full manual acceptance and the Phase 8 stale production-helper
scenario remain outstanding.

## Earlier owner acceptance candidate

The earlier owner candidate includes the merged Phase 6 baseline plus the
independently approved acceptance corrections at
`acc740113d1e7e056b5e7f1b2e3a0e3e21f24c27`:

- DMG: `dist/ReleaseRadar-0.1.9-acc7401.dmg`
- Version/build: `0.1.9 (1)`
- Package artifact commit: `09caafe0108496297684089603aa04c0cfffe361`
- DMG SHA-256: `bfb3e769f7f5acea37aeca0573a8a53ad484795fcbe2f36c07010c8f6fe7b046`
- Main executable SHA-256: `52a4a1a8015fde064582c8768828d60907b641d09d827c15806919c2b283e428`
- CodeDirectory hash: `cf90e9252c9b56e1699041d098987b37dea340ce`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The DMG verifies and mounts read-only; its bundle and nested code pass strict
signature and entitlement checks. Mounted executable and CodeResources match the
staged app. It is locally signed, not notarized or a generally distributable release.
Earlier 0.1.7 and diagnostic 0.1.9 packages remain preserved, not current candidates.

The [owner acceptance guide](../evidence/2026-09-11-phase6-owner-acceptance-guide.md)
covers the September 8–11 merged Phase 3A/3B–6E changes, backup and migration
preparation, low-risk navigation with disclosed Search preference writes,
disposable-project mutation checks, optional recovery checks and bug reporting.
Guide and signed-test closeout are committed at
`c9ca97f42d57ea6566bbc55c02f5271c09282d55`.

Under later explicit owner authorization, acceptance task
`01a091aa-e8bc-7d53-8005-dd59de3ee38b` completed an in-place installation of the
`acc7401` 0.1.9 candidate. It verified `/Applications/ReleaseRadar.app` signature,
version and executable identity against the candidate, and verified Pursuit startup
without a schema banner. The original 0.1.7 application remains preserved for
rollback. This bounded installation and startup check did not complete the full
manual acceptance guide and grants no authority for another installation, app
launch, or live helper restart.

The initial diagnostic run was 192/197. Its byte-exact goal identity regression
and fixture failures are corrected; six targeted tests and 114 affected tests pass.
Independent review approved the correction source with no Required findings.
Under subsequent explicit owner authorization for temporary signed test-service
registration, the corrected AgentBridgeTransportAcceptanceTests passed 16/16 and
CodexPluginLifecycleTransportTests passed 14/14. Post-run BridgeAgent was absent;
the pre-existing PluginLifecycleHelper retained PID 48996. Two earlier signed
Debug attempts lacked the XCTest debug entitlement and stopped before test loading;
they are not passing evidence. The normal signed Debug test host completed both
suites. Retained results and limitations are recorded in the guide.

Scoped automated correction and package verification are complete. The authorized
in-place installation and startup check are complete, while full owner manual
acceptance remains outstanding. The acceptance commits are local and unpublished.

## Restart helper recovery

The local `codex/restart-plugin-helper` candidate at
`a60b1fd2f5c56d145bcbc634fd0e3f75a8765f26` adds the Settings **Restart helper**
recovery action. It waits for asynchronous helper teardown before re-registering,
refreshes status without an install/remove/reinstall command, and restores managed
intent only after an exact clean match to the retained verified version and digest.

The author-produced focused run passed 54 of 54 tests with no failures or skips;
the app build and repository documentation check passed. Independent reviewer task
`01a092a5-95b6-7630-a9e9-8b77404f3d0f` approved the corrected candidate with no
remaining findings and is archived. Delivery-author task
`01a09295-0d2a-7cf2-a7c5-08a8bfb20d8a` completed its local closeout and is pending
archive after parent confirmation. No package, installation, or live helper
verification was performed for this newer change.

Owner-authorized task `01a092d8-9831-76c0-ba7c-c899f195bee5` built and verified
`dist/ReleaseRadar-0.1.9-a60b1fd.dmg` from reviewed closeout `07d8f877` (product
source `a60b1fd`) and committed the package at
`69f939563f2e4044b00b91a0c1c22424aecb84a8`. The locally signed
0.1.9 (1) bundle passed strict nested-code, Hardened Runtime, entitlement, DMG,
mounted-identity and installed-identity checks. The previously installed `acc7401`
app and the earlier 0.1.7 app remain preserved in separate rollback directories.

The stale 0.1.7 helper PID `48996` survived application replacement, but existing
startup recovery replaced it from the newly installed app before the Settings
action was activated. The task did not manufacture the stale condition. One
**Restart helper** activation then exposed the in-progress accessibility state,
replaced current helper PID `67535` with PID `67987` executing from
`/Applications/ReleaseRadar.app`, and finished with the success message and enabled
actions. Plugin inventory and bytes remained unchanged and Pursuit remained
visible. Final status is honestly **Modified**, not **Installed**, because the
installed bytes differ from the last managed receipt. The
[signed installation evidence](../evidence/2026-09-11-restart-helper-signed-installation.md)
records the result and limitation.

A later owner-supplied Settings screenshot shows plugin version `0.1.9` as
**Installed**. It is recorded as a later observation without inferring which
intervening action changed the earlier **Modified** state.

An attempted isolated process harness on `codex/restart-helper-dmg-live-test` used
an alternate launchd/Mach service, custom adapter, ad hoc unsandboxed helpers and a
sentinel exit. Independent review rejected it as evidence because it did not
exercise production `SMAppService` unregister/register and duplicated explicitly
rejected test machinery. The harness and its production-source seams were
withdrawn. Existing tests continue to cover asynchronous service ordering, exact
stale-to-clean receipt restoration and AppModel presentation; the installed check
covers the actual button and production service with an already-current helper.
The exact stale production `SMAppService` plus installed Settings button combination
remains unexercised.

## Authorization, limitations, and next work

The authorized Restart helper package, installation, and bounded live-check endpoint
is complete. No push, PR, merge, plugin installation/removal, owner SQLite access,
unrelated application mutation, external publication, notarization, Phase 7 work,
or cleanup was authorized or performed.

Application inventory, catalog binding/acceptance, and managed readback remain
unauthorized. The last recorded inventory was `bindingMissing`, `isComplete:false`
for `project-fffdc0e0b15b9b86`; local documentation checks do not establish managed
application synchronization. Full owner manual acceptance remains outstanding.

Phase 7 planning is independently approved at
`a0f22d965395248be6ec5928d2932d3a7ce5166d`. Phase 7 implementation remains paused
and requires separate explicit authorization. The next eligible owner work remains
the broader manual acceptance guide.

The owner explicitly deferred the stale production-helper acceptance scenario to
[Phase 8 production packaging and release readiness](../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#phase-8-deferred-stale-helper-acceptance--owner-decision-2026-09-11).
It remains outstanding rather than passed and does not block current manual
acceptance or Phase 7. Before broader distribution, Phase 8 must verify the real
fixed `SMAppService` stale-helper upgrade handoff through the installed Settings
button, including awaited old-process termination, current installed-helper
identity, fresh exact-identity plugin/receipt status, unchanged plugin/project data
and actionable failures. The [signed installation evidence](../evidence/2026-09-11-restart-helper-signed-installation.md#remaining-stale-helper-gap)
retains the accepted evidence and precise limitation.

A faithful isolated stale-helper check would require a separately provisioned,
logged-in macOS account or VM with its own GUI launchd domain, Codex home, Release
Radar store and installed signed app versions. None was created or configured.
This account's fixed service label and Mach service are occupied by the owner's live
helper, so manufacturing the precondition here would alter the working service and
owner state beyond the authorization granted. Provisioning that environment remains
separate future work and is not currently authorized.

Any future DMG containing changes after the recorded 0.1.10 package must use a
strictly newer semantic version with matching application, bundled plugin and DMG
versions. The current authorization does not extend to another package.

The release staging bundle and repository `DerivedData` remain temporary build
outputs. Earlier per-slice temporary diagnostics listed in the historical Phase 6
record also remain. No cleanup was performed; any cleanup requires explicit owner
authorization.
