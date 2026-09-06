# Release Radar: full-product architecture assessment and delivery plan

Date: 2026-09-06. Status: **Supporting; architecture and sequence proposed. Six
additional outcomes approved for roadmap inclusion on 2026-09-06.**

The owner also approved including the C8 OS-metadata validator repair described
below. It is a bounded repair within documentation reliability, not a new feature
or authorization to implement during this planning update.

This document assesses the complete product direction in the repository, including
unfinished proposals, all GitHub issues, project lifecycle repairs, RekonDesignSystem,
and agent execution reliability. It proposes a coherent implementation sequence.
It does not approve architecture changes, open implementation, change application
delivery state, or supersede accepted designs. [Progress](../progress.md) remains
the delivery ledger. Feature references below identify assessment rows, not new
application tickets or a second delivery ledger.

## Owner-approved roadmap additions — 2026-09-06

The owner approved including all six recommendations below. Their inclusion is
settled; detailed design, architecture amendments and implementation remain to be
approved in the applicable slice. This approval does not promote the whole plan
or other existing proposals to approved status. The existing six-goal/eleven-ticket
catalog remains intact; these references identify additional documented outcomes,
not newly created application tickets.

| Outcome approved for inclusion | Assessment reference | Planned delivery |
| --- | --- | --- |
| Requirements and decision traceability | P15 | Set identity/authority rules in slice 0; deliver explicit links and impact browsing with recorded planning in slice 5. |
| Plan revisions and change previews | P16 | Set baseline/approval rules in slice 0; deliver reviewable proposals and history in slice 5. |
| Delivery evidence tied to the actual code revision | P17 | Set evidence identity/freshness rules in slice 0; deliver the ticket panel in slice 6, with installed-version coverage verified in slice 8. |
| Ticket cancellation, replacement and splitting | P18 | Set lifecycle/history rules in slice 0; deliver complete revision and successor behavior in slice 5. |
| Workspace search and saved views | P19 | Use slice 4 navigation/query scope; deliver search, filters and saved-view restoration in slice 6. |
| Project health and guided recovery | C12 | Deliver the consolidated health view and initial recovery actions in slice 1; complete management, recovery and documentation observations in slices 2/3. Reuse existing diagnostic services. |

## Recommendation and confidence

**Retain the application and its core boundaries. Repair the continuity model and
replace the affected orchestration and navigation incrementally. A full rewrite
is not justified by the evidence.** The major modules are sensible: SwiftUI
presentation, framework-independent domain/store code, a typed mutation bridge,
bounded transport, and separately signed tools/helpers. The transactional store,
revision checks, replay receipts, managed artifact identities, five-lane policy,
Delivery Goals and Ticket Tasks are valuable working foundations.

The project is only partly coherent and maintainable today. Folder structure is
clearer than responsibility ownership. `AppModel` coordinates navigation,
projections, documentation, authorization, notifications and plugin state;
`OnboardingView` mixes a large workflow with UI; projection code combines SQL,
availability and display policy. More importantly, the product lacks a complete
project lifecycle contract. Individually defended boundaries have produced an
end-to-end deadlock. Documentation has authority metadata but contradictory
contracts and obsolete implementation-status statements. Tests cover many domain
rules while allowing an unusable owner journey to pass.

| Approach | Assessment |
| --- | --- |
| Continue isolated patches | Fast locally, but repeats contradictions among setup, recovery, planning, identity and export. Reject as the primary approach. |
| Retain core; revise shared contracts; deliver complete vertical slices | Recommended. Preserves working invariants and allows direct comparison with current behavior. Replace narrow subsystems when their existing structure obstructs the agreed outcome. |
| Restart the whole app | Recreates signing, sandbox, store, history, bridge and recovery risk while still requiring the same product decisions. Consider only if a separately approved product direction replaces local authority or a bounded slice proves the existing core cannot safely migrate. Neither is established. |

Assessment baseline: GitHub default tree `fcb432bf2c6f5e5bab63418adb9b6ec647e1baef`,
content-identical to local repair revision `ec511d8`. The canonical checkout has
older HEAD and extensive pre-existing documentation changes; it is not a clean
representation of that baseline. Seven GitHub issues were read, including bodies
and comments: six open, one closed. Source, controlling documentation, proposals,
design assets and selected installed UI were inspected. Ninety-five focused tests
passed during this assessment (onboarding, guidance, documentation preview and
store); that is not a full-suite or complete runtime acceptance claim. The exact
folder-picker timeout remains undiagnosed. Proposed screens were assessed against
their mockups, not claimed to exist in the running product.

## Findings that change the plan

1. **Blocking: registration depends on work the handoff cannot perform.** Setup
   persists the project, hides it while pending, and requires a phase to finish.
   The copied prompt handles repository guidance and expressly excludes delivery
   mutations. Checking status only observes phase existence. Source also requires
   existing managed-documentation prerequisites, so a genuinely blank repository
   needs an explicit bootstrap route. Repair the whole journey rather than make
   a status button invent a phase. See source references S1 and S2.
2. **High: reset cannot reconstruct authority from repository files.** Files do
   not restore the lost project graph, repository binding, accepted snapshot,
   audits or receipts. A recovery prompt cannot manufacture that evidence.
   Reconnect, relocate, seed, portable import and full backup recovery need
   distinct operations and truthful outcomes. Schema recovery currently leaves a
   store instance with immutable availability; refreshing projections does not
   reopen it. Plugin installation receipts also cannot substitute for inspection
   of installation state after reset. See S1, S3 and S8.
3. **High: lifecycle and portability contracts are incomplete.** Project editing
  is absent from the inspected general Settings/Overview paths. Archive/delete
   are open work. Path-derived project IDs, root-only older commands, restrictive
   foreign keys, audit retention and globally scoped opaque receipts complicate
   deletion/re-add and restoration. Archive v1 predates current goals, readiness,
   tasks and managed documentation. The RR-R10 design also describes importing
   v1 tickets into Backlog, conflicting with ADR-001's lane preservation and the
   lossless outcome. Resolve these contracts before export/import. See S1, S3,
   S7 and ADR-001.
4. **High: future planning needs exceed the scheduled implementation.** RR-RM1
   covers a joint design decision; RR-RM2/RM10 cover navigation and Help. This
   does not itself schedule delivery of Project Plan, unscheduled work, explicit
   phase lifecycle/order, workspace Goals or richer History. These directions
   need explicit delivery outcomes after their joint decisions, not omission or
   automatic promotion from proposal to approval.
5. **High: similarly named concepts have incompatible meanings.** Active phase
   is an owner-selected working context; proposed phase “Current” is lifecycle.
   Delivery Goals are phase-owned outcomes; proposed Goals screens also describe
   observed Codex goals. Ticket lanes, phase readiness, task completion and agent
   run status each have different authority. Conflating any pair creates later
   migration and UX problems. See ADR-003/004/005 and the planning/UX proposals.
6. **Medium: navigation scope already disagrees across features.** The latest
   dashboard loads all phases, but dependencies still use the active board and
   project-keyed graphs. Routes contain no phase/filter/detail history. Viewing
   another phase can therefore lose context on related navigation. Fix through
   one shared scope contract, not separate stacks for each new screen. See S4.
7. **Medium: freshness and history can mislead.** Documentation validation is
   not continuously reconciled with external changes (#18); relevant errors lack
   direct same-folder recovery (#19). Activity already aggregates multiple event
   types, but current ticket lane is attached to old events and cannot prove an
   event-time transition. Use shared observations and preserved event facts. S5.
8. **Medium: tests and delivery practice miss completion at the user boundary.**
   Onboarding tests can manually create the phase missing from the real handoff.
   Dedicated UI-test scaffolding is minimal, though hosted rendering tests do
   exist. Passing policy tests cannot prove a copied prompt, installation,
   folder authorization or compact inspector works. #9 is a discoverability
   problem with stacked scrolling, not proven missing task data. S2 and S6.

## Scope and source maturity

“Approved” below means an existing documented outcome, not authorization to
implement in this assessment. “Proposed” means a documented direction with
unresolved detail. “Repair” comes from owner reports or a verified gap. “Decision”
and “discovery” must terminate in an explicit conclusion and need not produce code.

The approved roadmap remains all six goals and all eleven tickets:

| Goal | Existing tickets | What is actually committed |
| --- | --- | --- |
| RR-DG1 | RM1, RM2, RM10 | Joint product/IA decision, coherent Back/Forward, Help and acceptance of that outcome. Additional proposed surfaces need explicit delivery scope. |
| RR-DG2 | RM5, RM6 | Authoritative lossless exporter/fixture, then complete transactional Portable Import. |
| RR-DG3 | RM7 | Prove a supported authenticated observer, or approve no-go with truthful unavailable behavior. |
| RR-DG4 | RM3, RM4, RM9 | Production wordmark, scoped warnings, distribution decision and required package verification. |
| RR-DG5 | RM8 | Companion pursue/no-pursue decision; pursue requires a separately approved boundary and delivery outcome. |
| RR-DG6 | RM11 | Role-agent execution decision; no implied orchestration engine or mandatory role matrix. |

GitHub coverage: [#1](https://github.com/joeroberts/release-radar/issues/1) is generic
Ticket Tasks adoption; [#3](https://github.com/joeroberts/release-radar/issues/3) is
bounded Run Guard extension-host discovery; [#9](https://github.com/joeroberts/release-radar/issues/9)
is inspector discoverability; [#18](https://github.com/joeroberts/release-radar/issues/18)
is documentation freshness; [#19](https://github.com/joeroberts/release-radar/issues/19)
is documentation access recovery; [#20](https://github.com/joeroberts/release-radar/issues/20)
is archive/restore/delete. Closed [#2](https://github.com/joeroberts/release-radar/issues/2)
records the owner-attribution disposition; it is not reopened as a product defect.
These issues are not a complete feature inventory; the documentation supplies
the wider direction confirmed by the owner.

## Feature-by-feature fit

### Project continuity and repository access

| Ref / feature / maturity | Current support and architectural fit | Complete outcome and decisive acceptance |
| --- | --- | --- |
| C1 Register, initialize and resume — repair | Persisted roots/bookmarks and setup exist; phase-gated visibility and incomplete handoff are incompatible with empty/unplaced planning. Retain authorization/store policy, replace setup orchestration. | A saved project is visible with an honest setup status even with zero phases. A blank folder has a supported documentation-bootstrap path; existing managed docs have explicit binding/acceptance steps. Creating the first real plan remains an authorized typed delivery action. Close/relaunch at every step preserves name, exclusions and progress; checking status creates nothing. |
| C2 Edit project — repair | Name is collected at setup; no general editor. Metadata edits fit the existing owner-operation pattern. | Rename and edit permitted metadata by stable project ID. Editing never creates a new project, resets setup, changes delivery state or implicitly relocates a root. Cancel, invalid input and unavailable folder preserve data. |
| C3 Same-folder reconnect and first-root attachment — existing + #19 | Core owner actions exist; documentation errors lack a direct route to them. | Restore folder access from the actual error, renew only the exact saved folder, retain IDs/history/binding. Invalid or changed docs must not prevent renewing permission; show the remaining catalog problem afterward. Legacy rootless attachment remains a distinct confirmed action. Diagnose picker behavior in the installed app. |
| C4 Repository relocation and worktree roots — existing, continuity gap | Typed relocation checks accepted catalog identity; multiple roots are supported but primary-root intent needs clarity. | Preserve project/artifact identities, authorize destination and keep the accepted-catalog boundary for relocation. Explicit primary root and separately authorized worktrees; no arbitrary evidence repointing. Wrong repository, lost permission and partial failure leave original associations intact. |
| C5 Archive and restore — #20 | No project lifecycle field/workflow. Add to existing store, not a second project registry. | Archive retains the graph/history and repository association, hides from default active views and suspends applicable operational activity. Restore changes lifecycle only and exposes access problems. Neither action needs a valid current catalog merely to manage local records. |
| C6 Delete — #20 | Goals/tasks/history foreign keys, audit protection and receipts make naive cascades unsafe. | Confirm exact project and retained-history policy; atomically remove its operational graph and local capabilities, cancel affected work, preserve other projects and every repository file. Late callbacks/old requests cannot mutate a re-added registration. Clearly distinguish deletion from full erasure. |
| C7 Backup, reset and recovery — repair | Migration preservation exists; no coordinated recovery across app/bridge connections and dependent services. | Separate preference reset, tracking-data reset and full backup restore. Quiesce all app-owned connections and pending work, replace state through app-owned operations, reopen services, inspect external plugin state, and recover missing permissions. Older backups cannot cause replay of already-sent notifications. A repository-only reconstruction is explicitly incomplete. |
| C8 Documentation validation, catalog acceptance and maintenance — existing + #18 + approved validator repair | Strong catalog/identity validator, generated indexes and typed operations. Refresh and status ownership are fragmented; blanket rejection of dot-prefixed paths makes ordinary Finder metadata invalidate documentation. | Apply the narrow OS-metadata discovery rule below. One root/registration-scoped observation drives Overview and evidence: checking, current, invalid, pending acceptance or inaccessible, with validation time. Authorized filesystem events plus activation/reopen invalidate stale success; coalesce reads and reject late results. Observation never accepts a catalog or repairs files. |
| C9 Evidence preview, identity and lifecycle — existing | Managed artifact locators and bounded reads are reusable; legacy paths remain distinct. | Preserve repositoryID/artifactID through relocation, archive and import. Render only bounded authorized content; rejected/stale/missing evidence stays explicit. Maintenance, preview and export use the same identity and custody rules. Never replace identity with a cached path to make a check pass. |
| C10 Portable export — approved RM5 | No complete exporter; seed import is not export. Existing v1 contract is too old. | Approve a revised complete archive, export all supported domain state and imported-history provenance, produce the acceptance fixture. Resolve multi-root and evidence-content policy explicitly. Reject unsupported state rather than omit it. Export is read-only and never claims to back up files or secrets it excludes. |
| C11 Portable import — approved RM6 | Validation/transaction foundations fit; implementation depends on C10. | Preview and revalidate exact exporter output, freshly authorize destination roots, reject identity/root collisions, restore the complete supported graph atomically with exported domain IDs and new local capabilities. Imported observations remain historical; failures leave no partial project. Round-trip tasks, goals, evidence and history, not merely ticket counts. |
| C12 Project health and guided recovery — owner-approved inclusion | Existing store, access, catalog, plugin and observer diagnostics provide the data; the consolidated owner workflow is missing. Extend C1–C9 rather than create a second diagnostic system. | One view identifies each problem, its affected project/root, last-check time and supported next action across folder access, catalog, store, plugin and observation. A successful check in one area cannot mask another failure. Actions invoke the existing exact-target owner operations and refresh the shared observation. Stale results, denied recovery and unavailable checks remain explicit. The health view must remain usable when the store itself is unavailable; viewing health never repairs or accepts anything automatically. |

### C8 bounded repair: tolerate ordinary OS metadata

The owner approved this repair direction for inclusion in the plan. The current
`RepositoryDocumentReader.isProhibited` and directory walk reject dot-prefixed
paths, following the [managed-documentation contract](../../design/managed-repository-documentation-contract.md).
This is a validator design defect: Finder metadata must not invalidate otherwise
valid documentation. Repeated deletion and changes to `.gitignore` are not the fix.

Start with an exact `.DS_Store` basename exclusion for ordinary regular files
during documentation discovery. Check file type without following symlinks before
excluding it; a symlink or directory using that name must not bypass existing
safety checks. Do not ignore all hidden files or everything matched by Git ignore
rules. Excluded metadata is not a catalog artifact and cannot be registered as
managed evidence. Keep actual documentation registration, root containment,
symlink protection and other prohibited-content checks intact.

Update the reader/validator behavior, the documented versioned exclusion rule and
the shipped catalog reference together, with an explicit compatibility decision
for installed validators. No database repair, repository rebinding, catalog
acceptance, metadata deletion or agent-rule change is part of this fix.

Acceptance uses the existing reader/validator tests and bundled checker:

- Valid documentation containing regular `.DS_Store` files at the docs root and
  nested collection paths validates. Creating, changing or removing only that
  metadata leaves the document inventory and catalog digest unchanged.
- Same-named symlinks/directories, other prohibited paths, unregistered actual
  documents and attempts to catalog the excluded metadata still reject.
- The app and bundled checker agree on the rule. Verify the installed reader/checker
  tolerates the canonical metadata file without deleting it, while separately
  reporting any real catalog, authorization or binding errors.

Deliver this bounded repair early, before relying on canonical documentation
validation to unblock other work. It does not depend on the lifecycle migrations
or the later automatic-refresh work in slice 3. Its implementation still requires
the ordinary explicit selection of that work; this update adds the plan only.

### Planning, work and owner navigation

| Ref / feature / maturity | Current support and architectural fit | Complete outcome and decisive acceptance |
| --- | --- | --- |
| P1 Overview and Project Plan — existing + proposed, RM1 decision | Overview and all-phase board loading exist; complete planning surface does not. Reuse authoritative projections. | Overview summarizes; Project Plan exposes all recorded phases, placed/unplaced work, dependencies and coverage. Current/selected/project totals agree. Unresolved intake remains outside recorded-work counts and has a separate incompleteness signpost. Empty/detail states offer the intended planning request, clearly copied rather than sent, with recoverable copy failure; formal changes still use authorized typed actions. Unknown, empty, unavailable and not-applicable states differ; inaccessible repository content never hides the persisted plan. |
| P2 Unscheduled work and placement — proposed | Tickets currently require phase and lane. This needs domain/storage/command changes, not a UI-only Backlog label. | One stable work identity with explicit optional placement. Recommended: unplaced work may hold outcome, evidence, dependencies and task definitions; execution lanes/completion operations require valid placement. Placement enters Backlog atomically and preserves identity/history. Do not invent a phase or sixth lane. |
| P3 Phase lifecycle, order and active context — proposed + ADR-003 | Only ID/name/project and an independently selected active pointer are present. Readiness is separate. | Add explicit lifecycle/order if selected in RM1; retain active phase as working context. Legacy lifecycle is unknown until assessed. Selecting a phase does not complete/reorder it or establish readiness. Replanning and phase moves preserve identity and respect accepted history. |
| P4 Phase Board and all-phase Work Board — existing + proposed | Five lanes, phase selection, filters and task counts exist. One board can support both scopes. | Reuse one Work Board with selected-phase and, if approved, all-phase scope. Every aggregate card names its phase, appears once and has consistent counts. Filtering/viewing does not mutate delivery; compact keyboard and VoiceOver access reaches every lane and inspector. |
| P5 Delivery Goals and readiness — delivered; wider scope proposed | Phase-owned goals with 1:N ticket membership, criteria, readiness and acceptance are useful working contracts. | Preserve explicit plan revision/readiness and owner acceptance. Recommend workspace Delivery Goals as aggregation of phase-owned outcomes first. Whether one outcome must span phases is a separate product decision requiring assignment/readiness/archive changes, not an incidental screen refactor. Completed and unassigned outcomes remain discoverable. |
| P6 Codex execution-goal links and semantic suggestions — proposed | Exact ticket/thread/observed-goal link is 1:1. This is not the Delivery Goal relationship. | If pursued, separately define 1:N link cardinality, provenance, owner-confirmed suggestions and collision/rejection handling. Suggestions never count as exact links or cause acceptance/notifications. Define the proposed unlinked-goal Needs Review rule with stable source identity and deduplication so refresh cannot create repeated attention items. Refresh preserves confirmed identity; unlinked, stale and unavailable remain distinct. Depends on real source identities for live behavior. |
| P7 Navigation, Back/Forward and deep links — approved RM2 | Current route contains destination/project only; viewed phase, filters and selected ticket have separate ownership. | One typed entry carries project, phase scope, goal filter, selected entity and restoration/focus context. Sidebar, controls, keyboard and in-app links share history. Goal→board→dependencies→Back/Forward restores exact context; branching clears forward history; deleted/archived targets recover honestly. Define relaunch policy; do not add external URL registration unless actually required. |
| P8 Dependencies — existing, scope defect | Stored edges can cross phases; displayed graph remains phase scoped and currently prepared from active phase. | Recommended project-wide graph with selected-ticket/phase focus, or explicitly named external stubs in a scoped view. Choose one in RM1. A nonactive-phase ticket opens its own dependencies and returns to the same board context. Wrong-project edges and cycles reject; dependencies never move lanes automatically. |
| P9 Ticket details and Ticket Tasks — delivered + #9 | Task-plan revisions, supersession, completion and read-only presentation exist. Stacked scroll regions obscure content. | Preserve task semantics while making the complete inspector discoverable and accessible at compact sizes. Task completion never implies ticket/goal acceptance. Placement/import preserve history; no-plan differs from load failure. Verify last-row access and focus, not only card rendering. |
| P10 Generic task-plan adoption — #1 | Existing revisioned commands suffice for writes; public query currently exposes only evidence inventory. | Add complete, scoped delivery readback, then owner-reviewable/resumable adoption for non-Accepted tickets. Atomic work may remain unplanned. Use exact revisions and replay receipts, separate evidence-backed past completion, and read back results. No external SQLite, accepted-history backfill or second reconciliation database. |
| P11 Activity / complete History — existing + proposed | Existing projection combines audit, review, execution and notification events. Reuse it. | Preserve immutable event-time facts and provenance; distinguish imported history from local actions. Later lane changes must not rewrite old event meaning. One filterable History surface, with empty/filter-zero/error distinctions, useful event detail and navigation into retained entities. |
| P12 Needs Review, acceptance and notifications — delivered, cross-feature evolution | Owner resolution, goal acceptance and Pushover/history exist. Shared event identity matters as linking/history grow. | Keep attention items distinct from acceptance gates and execution status. New event types require explicit eligibility and deduplication. Planning edits, task checkmarks, view changes, imports and observation refresh never masquerade as acceptance or resend completion. Archive/reset/deletion must reconcile pending work and unknown sends. |
| P13 Help — approved RM10 | No current Help route. Fits the final IA. | Contextual Help explains real setup/recovery, active versus viewed phase, planning/readiness, two goal domains, acceptance, history and portability. Copied requests are clearly not dispatched. An owner can complete initialization or find the next recovery action using controls that actually exist. Maintain Help in each delivered slice. |
| P14 Workspace execution-goal browser — proposed | Existing observations/links can support read projections; the proposed global browser is not delivered. This is a separate outcome from P5 Delivery Goals and P6 link changes. | Retain All Projects + All goals defaults, completed/unlinked observations, independent link identity/freshness/provenance, and project-wide associated work with phase identity. Derived execution summaries never become formal lanes or Delivery Goal states. Goal→all-phase board→Back restores exact filters/detail/scroll/focus; Clear filter stays on the board. RM1 chooses distinct Delivery/Execution views or destinations. Historical/unavailable presentation is useful but never counts as live visibility; live source and stable identities depend on I1. |
| P15 Requirements and decision traceability — owner-approved inclusion | Managed document identity, delivery IDs and dependency queries are useful foundations; explicit product-to-work relationships and impact browsing are missing. | Link requirements, outcomes, features, decisions, tickets and managed documents using stable identities and relevant revisions. Show what depends on a selected item and whether linked material has changed, is unavailable or is superseded. Keep authoritative prose in its existing document; links do not create a competing requirement store. Explicit relationships are evidence of recorded dependencies, not proof that every semantic impact is known. Any automated suggestions remain unconfirmed until deliberately adopted. |
| P16 Plan revisions and change previews — owner-approved inclusion | Phase/task revision checks exist; an owner-visible proposal and comparison across affected planning records is missing. | Compare a proposed change with its identified baseline: added, removed, moved or replaced work, changed dependencies/acceptance criteria, and recorded future-feature impacts from P15. Preserve rationale and review disposition. App-owned structured state and linked document versions retain their respective authorities. Reject a stale apply without partial changes; allow refresh/review. Approved changes to the app-owned graph apply atomically through typed audited operations; document edits follow the explicit repository/catalog workflow with separately reported outcomes. Neither automatically accepts delivery work or implies arbitrary execution authorization. |
| P17 Delivery evidence by code revision — owner-approved inclusion | Generic evidence/history exist; commit, PR, checks and installation are not a coherent owner-facing delivery view. | A ticket panel connects the relevant repository/commit, PR, scoped test results, documentation revisions and build/installed version where known. Show source, checked time, revision applicability and missing/stale/unavailable evidence. A test for an older revision cannot silently satisfy a newer one; a merged PR does not imply installation. Use explicit links and bounded authorized read adapters; preserve manual/local evidence paths. Viewing or refreshing cannot publish, merge, execute tests or accept work. |
| P18 Ticket cancellation, replacement and splitting — owner-approved inclusion | Tasks and goals have bounded supersession semantics; ticket-level withdrawal and successor relationships are missing. | Add ticket lifecycle distinct from the five execution lanes. Retain withdrawn/replaced work, reason and successor links; split work without copying completion or falsely accepting the original. Preview and reconcile dependencies, goal coverage, evidence and task history in the applicable plan revision. No dangling references or duplicated delivered credit; accepted history stays immutable, with separate follow-up work when needed. Default work views and counts distinguish withdrawn work from Accepted; history/search can retrieve it. Define active-work cancellation and run ownership explicitly; a ticket lifecycle change never proves an external run has stopped. |
| P19 Workspace search and saved views — owner-approved inclusion | Existing projections and planned typed navigation can support a local search surface; workspace search and persistent filters are missing. | Search authorized known records across projects, goals, tickets, decision references and history by ID/name/text. Save filter/scope/sort choices and restore them on relaunch through typed navigation. Results identify project and entity; archived/deleted/inaccessible targets recover truthfully. Failed or incomplete reads do not look like no matches, and an unsupported saved filter must not silently broaden its scope. Full document-content search is a separate later extension, not required for this initial outcome. |

### Integrations, presentation and execution reliability

| Ref / feature / maturity | Current support and architectural fit | Complete outcome and decisive acceptance |
| --- | --- | --- |
| I1 Supported Codex observation — conditional RM7 | Observer protocol and truthful unavailable/stale models exist; live event consumption does not. Runtime goal model lacks stable goal ID. | Prove attachment/authentication to the intended product/process before implementation. Then own subscription/reconnect/freshness, provider/thread/goal identities and scoped persistence. Wrong-project, delayed/duplicate/reordered events and outages cannot mutate formal state. If proof fails, approve no-go; ordinary delivery features continue. |
| I2 Codex plugin lifecycle — existing, reset/distribution gap | Fixed signed helper and official CLI boundary are valuable. Saved “never installed” receipt currently drives not-installed status. | After reset, reconcile observed installation through supported inspection; distinguish absent, modified, inconsistent and unavailable. Keep the four-method lifecycle helper separate from observation and execution hosting. Wider distribution must replace owner-specific path assumptions with a proven confined boundary. |
| I3 RekonDesignSystem — owner-requested integration direction | Compatible Swift/macOS baseline and reusable controls/tokens; app currently has no package dependency. | Adopt in the app UI target using a reproducible reviewed revision. Pilot complete onboarding/recovery/edit flows, then board/details/navigation/history. Map domain statuses explicitly, preserve native behavior and accessible identifiers, and verify compact/large-text/keyboard/contrast behavior. Theme and wordmark decisions precede broad replacement. |
| I4 Wordmark and maintenance — approved RM3/RM4 | Approved AppIcon exists; final production wordmark and scoped compiler warnings remain. | Deterministic light/dark wordmarks with licensed type or approved outlines; preserve approved icon. Fix optional-.none and test actor-isolation warnings without unrelated modernization. Validate appearance and affected tests. Existing other warnings are recorded, not silently folded into RM4. |
| I5 Distribution — conditional RM9 | Signed sandboxed owner-Mac build; Release uses Apple Development and helper exceptions name owner-specific roots. | Decide owner-only, direct distribution or other channel early. Owner-only can conclude not required; wider delivery requires portable helper/install behavior plus appropriate signing/notarization and actual install/upgrade/relaunch checks. Certificate changes alone are insufficient. |
| I6 iPhone companion — RM8 decision, broad proposed vision | Local projections and artifact identities are useful; cloud, publisher and mobile implementation are absent. | Decide full corpus and authority first. Draft includes planning, operational documents, evidence, history and agent status, not merely a status screen. If pursued, deliver that chosen outcome through bounded checkpoints with coherent publication generations, offline cache, inclusion/custody rules and account/deletion/recovery behavior. Live agent status depends on I1; delivery/document browsing does not. |
| I7 Independent role-agent execution — RM11 decision | Typed commands/audits exist; asserted thread IDs do not establish independent reviewer identity. | Decide whether the app should own execution at all. If pursued, define run/provider identity, ownership, capability limits, cancellation/recovery and verifiable attribution/review independence. Execution results are evidence for explicit delivery actions, never automatic lane changes. Avoid a role matrix or controller merely to improve this repository's agent habits. |
| I8 Run Guard extension host — #3 discovery only | Existing boundaries are useful precedents, not a host implementation. | Bounded first-party feasibility: UI containment, compatibility, grants/revocation, separate run state, owned cancellation and lifecycle history. No marketplace or public SDK. If both I7/I8 proceed, select one owner per run. In-process UI alone cannot enforce memory/process isolation. Existing-desktop guarding is a separate feasibility claim from guarding owned runs. |
| I9 Codex rules and hooks — owner-requested assessment, separate engineering task | Native command rules and lifecycle hooks can enforce some mechanical behavior; no configuration changes are made here. | Pilot narrowly scoped command restrictions, post-operation evidence capture and bounded completion reminders. Preserve STOP, approval waits and legitimate blockers. Hooks never grant publication authority, infer content quality or automatically commit/PR/mutate delivery. Verify actual installed Codex behavior before adopting configuration. |

## Shared contracts to settle before separate implementations

These are proposed defaults with named consequences, not an additional framework.
Approve or amend the relevant contract once, then implement it in the owning
feature. No schema-only foundation is a completed owner feature.

| Decision | Recommended contract | Features affected / decision timing |
| --- | --- | --- |
| D1 Identity and registration | Opaque IDs for newly created projects; preserve all legacy/exported domain IDs. Separate local registration generation from domain identity and device root capabilities. Expected project/registration identity accompanies mutations and project-owned receipts. | C1–C7, C10/C11, I6–I8. Decide before lifecycle migration or changed commands. |
| D2 Setup, availability and lifecycle | Project lifecycle, setup progress, folder/document availability and plan readiness are independent. Saved projects remain visible. Migrate recognized onboarding review markers into setup state; retain unrelated review items and saved exclusions. | C1–C8, P1–P5, Help. Decide before repairing onboarding. |
| D3 Delete and history retention | Default Delete removes operational graph/capabilities and retains immutable historical audits plus a minimal deletion receipt detached from the live-project FK. Confirmation explains retained content. Full erasure is a distinct explicit policy decision. | C5–C7, C10/C11, P11/P12, I6. Owner must select retention before deletion implementation. |
| D4 Planning identity and placement | One work identity; explicit optional phase/lane placement; phase lifecycle/order and ticket withdrawal/replacement lifecycle separate from active context, readiness and execution lanes. Same-project moves and successor relationships preserve history and explicitly reconcile dependencies, goal coverage and task/evidence references; accepted work remains immutable under current policy. Cross-project transfer/clone is not implicit. | P1–P5/P8/P9/P18, portability and companion. Decide logical contract with RM1; implement together with useful planning behavior. |
| D5 Outcome scope and execution identity | Workspace Delivery Goals initially aggregate existing phase-owned outcomes. Keep observed execution goals separate. Retain the separate workspace execution-goal browser (P14), including unlinked/completed observations; recommend clearly separated Delivery and Execution views in the workspace Goals destination. Cross-phase outcomes and 1:N execution links remain explicit choices, with schema/acceptance consequences described in P5/P6. | P4–P6/P14, I1, P11/P12, C10/C11, I6. Decide before final Goals UX; no speculative cardinality migration. |
| D6 Navigation and query scope | One typed context across Overview, Plan, Board, Goals, Dependencies, History, health and search. One Back/Forward stack; authorized scoped read APIs reuse domain policy without external SQL. Search, impact links and saved views navigate by stable identity and preserve scope. | C12, P1/P4/P7/P8/P10/P11/P13/P15/P19. Decide with RM1 and deliver first through the existing nonactive-phase journey. |
| D7 Event facts and provenance | Stable event identity and event-time facts; separate local audit, imported history, external observation and notification delivery. Historical unknown fields stay unknown. | C6/C7/C10/C11, P6/P11/P12, I1/I6/I7. Define before archive/history changes. |
| D8 Artifact custody and freshness | Repository catalog owns document identity/authority; app accepts snapshots explicitly. One scoped validation observation; pending content never becomes accepted through watching, reconnect or import. | C3/C4/C8–C11, I6. Preserve accepted boundaries unless explicitly revised. |
| D9 Companion authority | Recommend Mac-authoritative delivery and repository-authoritative documents, with explicit read-only cloud publication. This still needs an approved cloud boundary. The draft's alternative cloud authority/document relocation is a larger product choice, not synonymous with sync. | I6, C7/C10/C11, artifact custody/distribution. Decide at RM8 before CloudKit or asset movement. |
| D10 Execution and distribution ownership | Keep observer, delivery command bridge, plugin installer and any executor distinct. Defer execution hosting until its decision/discovery proves a needed outcome. Record distribution audience early. | I1/I2/I5/I7/I8; affects helper entitlements and mobile capabilities. Feasibility can proceed independently of planning UI. |
| D11 Presentation | Adopt RekonDesignSystem components directly, with a small explicit mapping of app statuses. Approve dark-only versus adaptive theme before a wholesale UI pass; production light/dark wordmarks do not by themselves establish an adaptive app palette. | I3/I4 and all visible slices. Decide theme/pilot before broad adoption. |
| D12 Traceability and change authority | Preserve the source identity/version of requirements and decisions, typed relationships to delivery work, and the affected phase/task/document baselines of a proposal. Record rationale/disposition and reject stale application through existing revision checks. Explicit links reveal recorded impacts; neither prose inference nor proposal approval changes delivery state automatically. | P15/P16/P18, History, C10/C11 and I6. Set the shared contract in slice 0, then implement in slice 5; no generic change-control engine. |
| D13 Delivery evidence identity | Associate evidence with repository and source revision, test scope/result source, documentation version and build/installation identity as applicable. Keep expected evidence, reported observations, source freshness and owner acceptance distinct. Bounded source-control read access requires its own authorization; it does not depend on live Codex observation. | P17, P9/P11/P12, C9–C11, I5/I6/I9. Decide with the early contracts; deliver in slice 6 without adding automatic GitHub mutations. |

### Migration and recovery implications

Existing IDs must not be rewritten simply because they were derived from paths.
Reauthorization, relocation and archive restore preserve the local registration.
Portable import preserves exported domain IDs but creates a new local registration
and fresh capabilities; it rejects live collisions. An ordinary re-add after
deletion must not accidentally reuse identity. Full backup restoration preserves
the backed-up graph but rotates or invalidates active request generations so pre-restore
callbacks cannot apply. Cloning is a different operation requiring ID and possibly
repository-identity remapping, and is not currently a committed feature.

Deletion needs more than `DELETE FROM projects`: newer relationships use NO ACTION;
the audit FK uses SET NULL while generic callbacks prohibit audit changes; final
audits cannot reference a removed live row; request receipts lack project ownership.
Implement narrowly app-owned migration/deletion policy without globally relaxing
audit protection. A deletion transaction and subsequent authorized restore must
agree on historical project identity and replay scope.

Revised archive sections must include readiness/revisions; Delivery Goals,
criteria and assignment history; task plans, definitions, order, supersession and
completion; selected lifecycle/setup facts; and managed repository/artifact
identity with the accepted snapshot and retired artifact IDs. Assignment events
currently reference audits, while v1 excludes audits. Retain source historical
provenance explicitly, never fabricate locally executed audits; the import itself
gets a real destination audit. This requires an explicit ADR-001 revision.

Resolve the v1 lane conflict explicitly: the RR-R10 design's Backlog conversion
is not a lossless restoration of the ADR-001 archive. Recommended revised import
preserves source formal state and historical provenance, validates the supported
planning graph, and separately revalidates destination access/evidence before new
execution. Unsupported or inconsistent state must reject precisely, not silently
rewrite lanes or grant readiness through an import bypass. Approval must settle
this rule before the exporter-produced fixture becomes the import contract.

Choose explicit portable root slots with fresh destination mapping if multi-root
continuity is required; otherwise retain precise rejection of unsupported projects.
Choose graph/references-only versus a bounded evidence-asset package. The current
JSON contract does not back up repositories or referenced bytes. Neither choice
may be advertised as the other. Every later authoritative model addition extends
the archive contract and round-trip tests in the same feature change.

The newly approved outcomes add durable relationship/proposal/evidence metadata,
not another persistence authority. Migrations and archives must retain traceability
source references, proposal baselines and dispositions, ticket lifecycle/successor
history, and revision-attributed delivery evidence. Existing work has no inferred
links, fabricated proposal history or invented test provenance. Define whether
saved views belong to project portability or local workspace preferences; exclude
device capabilities and credentials. Imported external evidence remains historical;
any remote revalidation uses separately authorized readback after import, not a
network side effect of the import transaction. Health observations are recomputed
after restore. The companion's selected corpus
must explicitly account for these additions if pursued.

A full local backup includes a consistent store snapshot, audits, receipts,
notification history and configuration. It is not Portable Import. Bookmarks need
revalidation; Keychain secrets and installed plugins are not recovered merely by
copying SQLite. Recovery must stop admission, bridge callbacks and pending work,
close every app-owned store connection, restore through the app, rebuild dependent
services and reconcile unknown external sends before resuming. Never unlink a live
database or infer current plugin installation from a wiped receipt.

## Target organization with the fewest useful boundaries

Keep existing targets and feature folders. Do not introduce a generic workflow
engine, event-sourced replacement store, dependency-injection framework, plugin
platform or second persistence authority to execute this plan.

```mermaid
flowchart TD
    UI[SwiftUI features and RekonDesignSystem] --> Context[Navigation and feature state]
    Context --> Queries[Scoped read projections]
    Context --> Owner[Typed owner operations]
    Agents[Agent tools] --> Bridge[Typed authorized bridge]
    Bridge --> Commands[Domain commands and policy]
    Owner --> Commands
    Commands --> Store[App-owned transactional SQLite and audit]
    Queries --> Store
    Docs[Authorized repository reader and catalog validation] --> Queries
    Observer[Supported read-only Codex observer] --> Observations[Attributed stale or live observations]
    Observations --> Store
    Optional[Optional cloud publisher or execution adapter] -. approved boundary only .-> Context
```

Move responsibilities when their feature is touched: setup/continuity coordination
out of `OnboardingView`; typed navigation history out of scattered view state;
documentation freshness into one existing-service-based observer; notification and
plugin lifecycle ownership out of unrelated `AppModel` logic. `AppModel` remains
composition and app lifetime, not the implementation of every workflow. Keep
domain policies and store transactions in Core. Reuse query projections for views
and authorized readback with explicit completeness; avoid both arbitrary SQL APIs
and screen-specific duplicate business rules. Retain bounded reader/path/symlink
protection at every artifact boundary.

The proposed CloudKit publisher, if selected, is an app-owned adapter with a
transactional outbox and coherent publication generations. It does not allow a
phone to write local delivery data. Execution hosting, if selected, owns its runs
and publishes attributed results; it receives only the capabilities chosen in its
approved boundary. Neither is needed to repair the current product.

## RekonDesignSystem integration

The reviewed local package is `RekonDesignSystem` under the owner's UILib repository.
It uses Swift tools 6 and macOS 14, matching this app, with no third-party package
dependencies. No release tags were present at review, so choose and record a
reviewed reproducible revision/resolution strategy rather than inventing a version
or committing an owner-specific absolute package path.

Use its theme, typography, borders, elevation, motion, tones, buttons, text fields,
cards, badges, callouts, section panels and dialog surfaces directly in the app
target. Core must not depend on it. Its current palette is fixed dark; compact
density applies to selected components, not all native controls. Its string-based
picker is not a domain identity API: use an ID-safe adapter or native typed picker
for phases/goals with duplicate display names. Navigation, data loading, focus,
announcements, keyboard commands, errors and responsive composition remain app
responsibilities. Avoid a general wrapper library around every component.

First approve the app's theme/status mapping and inspect a complete setup/recovery/
edit pilot. Then migrate board/details and existing shared controls as those flows
are repaired; apply the same components to the new planning and history surfaces.
Preserve the approved AppIcon; finish the RM3 wordmark using deterministic licensed
type or outlines. Compare relevant approved mockups and explicitly adopted proposal
mockups with the running app at compact/wide sizes, increased contrast, keyboard
and VoiceOver. A package build or screenshot alone is not UI acceptance.

## Integration feasibility and boundaries

The current [official App Server documentation](https://learn.chatgpt.com/docs/app-server)
describes startup-selected transports and labels WebSocket experimental/unsupported.
It does not establish a supported authenticated external connection to this running
desktop instance. RM7 needs a bounded proof against the actual installed product;
starting another server does not prove attachment. Add no private-state scraper.
Live observation also needs stable goal identity and a consumed event stream, not
just a transport. An approved no-go must leave useful delivery tracking available.

RM8 must choose between read-only publication retaining existing authority and the
draft's broader cloud-authority/document-custody change. If pursued, include current
goals/readiness/tasks, selected operational documents/evidence/history, cache and
asset limits, inclusion/privacy, account switch, deletion, reset and schema upgrades.
Separate local commit time, publication time and source observation freshness;
recent upload cannot make old Codex state live. Apple documents asynchronous
CKSyncEngine scheduling, persisted engine state and app-specific error handling;
CloudKit subscription metadata is distinct from owner delivery mutations.
[Apple CKSyncEngine reference](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)
is a feasibility source, not authorization to add entitlements or cloud resources.

RM11 and #3 must agree on owned-run identity, capabilities and attribution if both
are pursued. An asserted role/thread is not proof of independent review. Keep run
state separate from delivery state, and do not reuse the plugin lifecycle helper
as a controller. A fixed first-party host is the discovery boundary; marketplaces,
public SDKs and general orchestration are outside it. RM9's distribution choice
must account for portable helper behavior and nested executables, as well as
[Apple signing/notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Execution reliability: what rules and hooks can enforce

### Operating baseline and task ownership

The owner selected the operating model recorded in
[ADR-007](../../architecture/ADR-007-proportional-delivery-validation.md) and root
AGENTS.md: an orchestrator with no subagents coordinates separate delivery tasks;
a separate chief architect maintains whole-product alignment. Writers use worktrees;
delivery tasks may use bounded subagents. Independent review uses a fresh task for
one candidate and its corrections. Integration has one owner for a bounded set,
and the orchestrator normally owns progress and delivery follow-through. These
capabilities do not imply a mandatory task for every role.

The chief architect checks affected shared decisions D1–D13 and future consumers
before a slice commits to a conflicting contract. Link relevant constraints in the
brief, separating approved behavior from proposed direction. Worker conclusions
cannot promote proposals or add scope. Continuing architectural responsibility
survives conversation replacement through the existing ADRs, designs and this plan.
No feature depends on undocumented memory in a long-running agent.

Root AGENTS.md is the single model-assignment table. Model and effort are explicit
task settings chosen for ambiguity and consequence; Luna/Terra handle suitable
bounded work, Sol complex delivery, and Astra whole-product judgment. Escalation
addresses a named unresolved problem within its authorized ceiling, after checking
context and tooling. **Ultra is prohibited everywhere, including subagents and
escalation.** Review independence and acceptance criteria are unchanged by model
choice. Review findings do not create another review layer.

The owner authorized updating/reviewing these operating documents and establishing
a local committed baseline. The
[baseline brief](../task-briefs/2026-09-06-operating-baseline/operating-baseline-brief.md)
defines this documentation task. Owner review/approval of the committed baseline
precedes the new-task pilot prompt; no pilot is launched by this update.

The first proposed pilot is the C8 OS-metadata validator repair above: Terra Medium
delivery, Sol High independent review covering reader correctness and filesystem
safety, and bounded Astra High chief-architect input on the compatibility contract
if needed. Use one review task for those concrete risks, not separate approval
layers. Start from the approved baseline commit on
`codex/full-product-architecture-plan`, not the old default checkout. The pilot
brief must name its authorized endpoint and verify source behavior and the shipped
contract; any installed-app change needs explicit authorization. It excludes the
broader freshness work, lifecycle migrations, owner-state repair and hook rollout.

Pilot completion uses the agreed outcome, affected documentation, direct regression
checks, required independent review and authorized commit/PR endpoint. Record a
short result on follow-through, context gaps, rework and usage where available in
progress. Do not build a scorecard or recursive evidence system. The pilot is for
this repository's delivery process, not approval to build I7's in-app execution
engine. All 40 assessed capabilities and their approval distinctions remain intact.

### Separate rules and hooks implementation

The user asked about actual [Codex rules](https://learn.chatgpt.com/docs/agent-configuration/rules)
and [hooks](https://learn.chatgpt.com/docs/hooks), not more prose in AGENTS.md.
They can improve mechanical follow-through, but cannot settle ambiguous product
scope or judge whether a feature truly meets its intended outcome.

Rules control matching command permissions; they do not require a missing test,
commit or PR to happen. Prefix matching and shell wrappers limit what they can
express. Effects depend on the installed runtime and permission mode. Hooks can
inspect/block supported tool invocations, observe results and request a bounded
continuation at Stop. Post-tool hooks cannot undo a completed action, and covered
tool paths are not a universal security boundary. Verify behavior in the installed
Codex version before relying on it. Avoid parsing undocumented transcript internals.

Proposed small pilot, as a separately authorized agent-configuration task:

| Mechanism | Useful enforcement | Required escape/boundary |
| --- | --- | --- |
| Rules / PreToolUse | Block narrowly identified unauthorized destructive or external actions; validate relevant command arguments for supported tools. | Preserve the actual authorization model; wrappers/MCP paths need their own supported coverage. Do not claim a universal sandbox. |
| PostToolUse | Record actual test/commit/PR outcomes and failures for the active task, using existing command results and a small bounded local record only if necessary. | Associate evidence with the changed scope/revision; account for asynchronous command completion. Tool success alone is not product success. |
| Stop | Remind an active implementation task of a missing agreed check, documentation disposition, local commit or authorized PR endpoint. | Permit reviews/questions, approval waits, explicit blockers, user STOP and interruption. Use stop-hook continuation context and cap corrective attempts; report a persistent failure rather than loop. |

Do not auto-commit, auto-publish, accept delivery work or invent authorization in a
hook. Hooks are additive and may execute concurrently, so they are not an ordered
pipeline. Do not require the entire dirty checkout to be clean; distinguish task
changes from the owner's pre-existing work. Documentation impact may legitimately
be “none,” with a reason. Content quality and scope fit still require direct review.

For each implementation slice, put a short delivery endpoint and change-specific
checks in its existing brief: what working behavior completes it, which docs change,
what local commit is expected, and whether PR/push/merge/install are authorized.
Use existing tests and Git results. Do not build a new task database, process
scorecard, transcript validator or mandatory reviewer matrix. Pilot hooks after
the actual test selection and endpoint are clear, then keep only mechanisms that
prevent a demonstrated failure without creating new deadlocks.

## Delivery sequence and dependencies

Sequence describes complete outcomes and prerequisites, not authorization or live
ticket state. Several independent decisions can proceed concurrently; product
repair must not wait for an observer, companion or execution-host feasibility result.

| Slice | Complete outcome | Dependencies and boundaries |
| --- | --- | --- |
| 0 Joint contract reconciliation | Owner selects/amends D1–D13 as applicable; RM1 resolves the coupled IA/planning meanings; update affected accepted artifacts only under that explicit approval. Retain the six newly approved scope additions; resolve their detailed contracts without reopening the inclusion decision. Record other proposed feature outcomes so they cannot be lost. | This proposed assessment is the input. Resolve lifecycle/identity and planning semantics now; detailed APIs and task briefs belong to each upcoming slice. No hidden infrastructure build. |
| 1 Usable project lifecycle | C1/C2/C3/C12 plus setup state, consolidated health and truthful registration readback: create/resume/edit a visible phase-less project, bootstrap docs through explicit steps, recover access directly. RDS pilot and Help for these flows. | D1/D2/D8/D11. Preserve store policy. Regression covers copied handoff and relaunch, not a manually inserted test phase. |
| 2 Safe management and recovery | C4–C7: managed relocation/root handling, archive/restore/delete, coordinated backup/reset restoration, installed-plugin reconciliation and their C12 health/recovery actions. | D1–D3/D7/D8; complete deletion retention and stale-command behavior first. Deliver bounded substeps with owner-visible recovery; no destructive migration without explicit owner authorization. |
| 3 Current documentation and evidence | C8/C9/#18/#19 share freshness and recovery. Overview, evidence and C12 health agree after external edits, access loss and catalog changes. | Deliver C8's bounded OS-metadata validator repair early and independently; the broader freshness work uses lifecycle generations from 1/2. Can overlap navigation work with separate file ownership. Watching never accepts or repairs. |
| 4 Coherent navigation and inspector | RM2's existing-surface journey, P7/P8 and #9: nonactive phase → ticket → dependencies → Back/Forward; accessible inspector and shared RDS controls. | D6 and agreed IA. Useful before new screens; no separate history implementations. |
| 5 Complete recorded planning | P1–P4/P15/P16/P18: Project Plan, unresolved-intake signposts, copied-not-sent planning requests, chosen unplaced-work rules, lifecycle/order, placement and chosen shared-board scopes; explicit requirements/decision links, impact browsing, plan-change previews and ticket withdrawal/replacement/splitting with complete authoritative readback. | D4/D5/D6/D12; P15/P16/P18 inclusion is approved, while detailed contracts and the other proposed outcomes still require the applicable decisions. Preserve five lanes and accepted history; add migrations, commands, errors and archive representation together. |
| 6 Outcomes, tasks and history | Workspace Delivery Goals and the separately identified execution-goal browser (P14), generic task adoption (#1), revision-bound delivery evidence (P17), workspace search/saved views (P19), event-time History and coherent attention semantics; RM10 Help completes the selected owner journeys. P6 execution links/suggestions only if separately selected. | D5–D7/D13; scoped read APIs and slice 4 navigation precede adoption/search; no new task engine. Some current-ticket adoption/history work can proceed before slice 5 once shared contracts settle. P14 must retain historical/unavailable distinctions; live visibility remains dependent on I1. |
| 7 Portable continuity | RM5 complete exporter/fixture, then RM6 transactional importer, with installed round-trip/recovery. | Archive decision D7/D8 and supported authoritative model in slices 1/2/5/6. Export may ship earlier against the current model if it is complete and every later model change extends it; importer never precedes an exporter-produced fixture. |
| 8 Production presentation/package | Finish RDS coverage and wordmark, scoped RM4 maintenance, package acceptance for chosen RM9 audience, and verified build/installed-version links in P17. | RDS begins in slice 1, not here. Distribution decision is early; final signed install/relaunch acceptance occurs on the delivered feature set. |
| Parallel decisions | RM7 supported observation; RM8 companion; RM11 roles; #3 host discovery; early RM9 audience; I9 hooks pilot. | Each has a bounded proof/decision and independent result. Pursue opens a separately approved complete outcome; no-go closes the decision without placeholders. |
| Conditional follow-on delivery | Selected live observer, full selected companion corpus, selected role execution/Run Guard. | Observer proof for live agent visibility; lifecycle/event/artifact contracts for cloud; one run owner for execution. These may be declined without making core delivery tracking incomplete. |

Do not gate every early repair on detailed design of every later optional feature.
Set the shared semantic boundaries now, then write only the brief needed for the
next coherent slice. Do not call a schema migration, design decision, status-only
mobile prototype or static UI completion of the broader feature it supports.

## Verification and delivery completion

Use the existing Xcode scheme and XCTest suites. Select tests by behavior; retain
the isolated XCTest host and synthetic stores, never the owner's database. Native
command shape, with one or more applicable `-only-testing` selections:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/verification \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests
```

| Change | Minimum meaningful verification |
| --- | --- |
| Documentation-only plan/decision | Catalog/index check, diff review and one independent substantive review. No product test rerun solely for prose. |
| Onboarding/access/lifecycle | Focused policy/transaction tests plus real UI-to-app integration journey, restart/resume, invalid catalog/access, saved exclusions, wrong identity and rollback. Installed authorization dialogs need runtime verification. |
| Persistence/deletion/reset/archive | Relevant migration/store/replay/goal/task tests, complete synthetic graph preservation or removal, fault/rollback paths, all-connection recovery, stale request rejection and notification unknown-outcome behavior. Round-trip complete export data. |
| Navigation/planning/tasks/history | Scope and revision tests plus actual nonactive-phase/back-forward journey, both goal domains and unlinked/completed execution observations, unresolved intake excluded from recorded counts, copy success/failure, event-time facts, unplaced→placed identity preservation, compact inspector, keyboard/VoiceOver and adopted mockup comparison. |
| Docs/evidence observation | Existing bounded reader/path tests plus C8 regular-metadata tolerance and preserved rejection cases; external edit, stale callback, invalid/pending/inaccessible transitions, same-folder reconnect and relocation distinction; verify no implicit write/acceptance. |
| Integrations/distribution | Prove the specific authorization/transport/capability boundary, failure/reconnect/cancellation as applicable, and signed installed launch/relaunch. Synthetic snapshots cannot establish a supported live endpoint. |

Run broader suites when a migration/shared policy or actual integration risk
justifies them; do not repeatedly run every suite for every small correction.
Existing hosted rendering tests are useful but do not replace installed workflows.
No standalone formatter/linter configuration was identified in the inspected
baseline; do not invent mandatory tooling. Add regression cases to existing suites
at the lowest layer that exercises the failure.

Each material slice requires direct verification and the applicable independent
review under ADR-007: ordinary code/QA review; additional architecture, security,
UX or sequencing expertise only for its concrete boundary or risk. UI completion
also requires the repository's independent QA and actual accessible/recoverable
behavior. A single qualified reviewer may cover multiple relevant concerns;
do not review reviews or add evidence layers to prove that review happened.

Before local commit or authorized PR: review the actual scoped diff, update
materially affected docs/catalog/indexes, record concise results and limitations
in progress, then create the agreed commit/PR. State an external authorization or
environment blocker explicitly rather than silently stopping short or fabricating
completion. Passing compilation does not prove runtime behavior, and a closed task
or old accepted catalog does not prove the installed project is healthy today.

Direct acceptance for the six additions belongs in their existing feature suites:

- C12: mixed health states, unavailable store, stale observation, denied recovery
  and correct exact-target action; no implicit mutation from viewing/refresh.
- P15/P16: stable links and reverse impact query, changed/missing source versions,
  exact proposal diff/rationale, stale baseline rejection and atomic graph apply;
  document/app outcomes stay distinct and accepted work is not auto-transitioned.
- P17: correct repository/revision association, outdated tests, unavailable remote
  checks and unknown installed version; refresh cannot publish or accept work.
- P18: withdrawal/replacement/split preserves history, reconciles dependencies and
  goal coverage, rejects invalid successors, and cannot duplicate delivered credit.
- P19: authorized multi-project results, empty versus incomplete/error states,
  saved-filter relaunch/migration and navigation to archived or missing records.

## Documentation reconciliation and keeping the plan coherent

The catalog is useful and should remain. Repair conflicting content, not add
another authority system. On approval, reconcile these exact sources:

| Source | Conflict or stale claim | Required reconciliation |
| --- | --- | --- |
| Dashboard design, onboarding and mutation principles | Phase-required completion and guidance-only prompt deadlock; early “no delivery gates” language conflicts with accepted readiness/acceptance rules. | Adopt complete setup semantics and distinguish authorization/readiness/acceptance from agent execution. |
| ADR-001 archive v1 | Missing newer domain sections; one-root constraint; audit exclusion conflicts with retained assignment-event history; no-cloud boundary versus companion draft. | Revise archive explicitly. Keep cloud boundary unchanged unless RM8 approves a separate change. |
| ADR-003 and Project Plan proposal | Active context versus proposed lifecycle “Current.” | Retain one active-context authority and choose separate lifecycle/order names. |
| ADR-004/005/006 headers and implementation claims | “Pending/proposed” text competes with active controlling catalog and delivered behavior. | Reconcile status after checking approvals; do not infer authority from a header or mark proposals implemented. |
| Managed-documentation contract / shipped catalog reference | Blanket prohibition of hidden OS files causes `.DS_Store` to invalidate otherwise valid documentation. | Implement C8's narrow, tested discovery exclusion and document its versioned compatibility rule; retain artifact and filesystem safety requirements. |
| RR-R10 archive statements / roadmap | Export/import remain future RM5/6; the design requires v1 lane conversion to Backlog while ADR-001 preserves source lanes and DG2 requires lossless continuity. | Approve one versioned preservation/readiness contract, reject unsupported state without omission, and state delivered capability accurately. Keep RM10 Help distinct from completed RR-R10. |
| Planning/UX studies and mockups | Outdated no-phase-discovery claim; two goal domains; additional surfaces not scheduled as implementation. | Preserve intended jobs, update obsolete diagnosis, make chosen IA and added outcomes explicit, label declined alternatives. |
| Progress | September 2 acceptance/readback describes historical state, not the reset installation today. | Retain concise historical pointers; record current task and current observed limitations without reopening accepted work. |

For a new feature or bug, change the relevant row in this document and only the
affected decisions/dependencies, then update its owning design/ADR when behavior
changes. Ask four practical questions in the existing brief: which identities or
authorities change; which existing/future capabilities consume that change; what
must migrate/round-trip/recover; which complete user journey proves it. If the
change introduces a real product direction, add a row before implementation.
This is a compatibility check, not a new gate engine or ledger. Scope is still the
owner's request; future compatibility does not authorize speculative implementation.

## Assessment limitations and current activation state

The installed validator rejects the canonical repository's `docs/.DS_Store`.
This is the planned C8 product repair, not a recurring owner-cleanup prerequisite.
Supported inventory reports no accepted
repository binding for the current Release Radar registration. That is consistent
with the reported post-reset mismatch and differs from the historical September 2
acceptance. Existing files alone do not establish restored app authority.

This plan can be reviewed as proposed repository documentation. Its catalog change
remains unaccepted by the app. Implementing C8 does not itself restore a missing
binding or accept a catalog; those operations remain distinct from the validator
repair and the plan's product decisions. Do not present this draft
as an accepted application snapshot or reconstruct missing audits. No application
state or agent configuration was changed during this planning pass.

The assessment does not prove absence of all defects, provide a full security scan,
or reproduce the reported picker timeout. Source-level missing editing and the
onboarding deadlock are stronger findings than those unresolved runtime reports.
The 95 passing tests do not cover the entire product. Clean-worktree documentation
validation and independent plan review are recorded in progress; canonical/app
validation limitations remain explicit rather than being hidden by isolation.

## Sources and traceability

Controlling documents and directional inputs:

- [Documentation catalog](../../catalog.json) and [documentation entry point](../../README.md).
- [Application boundaries / portable archive v1](../../architecture/ADR-001-release-radar-boundaries.md), [plugin lifecycle](../../architecture/ADR-002-codex-plugin-lifecycle.md), [active context](../../architecture/ADR-003-active-phase-selection.md), [goals/readiness](../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md), [Ticket Tasks](../../architecture/ADR-005-ticket-task-work-plans.md), [managed documentation](../../architecture/ADR-006-managed-repository-documentation-contract.md), [proportional validation](../../architecture/ADR-007-proportional-delivery-validation.md).
- [Dashboard product design](../../design/agent-driven-delivery-dashboard-design.md), [managed documentation design](../../design/managed-repository-documentation-contract.md), [active phase](../../design/release-radar-active-phase-selection-design.md), [plugin lifecycle design](../../design/release-radar-codex-plugin-lifecycle-design.md), [goal/board presentation](../../design/release-radar-delivery-goals-phase-board-design.md), [task presentation](../../design/release-radar-ticket-tasks-design.md).
- [Approved six-goal/eleven-ticket roadmap](../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md), [RR-R10 implementation plan](2026-08-29-delivery-goals-roadmap-readiness.md).
- Proposed [Project Plan](../../design/release-radar-project-planning-ux-proposal.md), [UX study](../../design/release-radar-ux-redesign-study.md), [interactive study](../../design/release-radar-ux-redesign.html), [companion](../../design/cloudkit-iphone-companion-draft.md), [mockups and maturity](../../design/README.md), and [brand](../../brand/README.md).
- RekonDesignSystem local package: `Package.swift`, `README.md`, `docs/integration.md`, `docs/compatibility.md`, `docs/accessibility.md`, `docs/release-policy.md` and public component source, inspected in the separate owner-designated UILib repository. No changes were made there.

Code references use the immutable reviewed GitHub tree so they do not misleadingly
point into the older canonical checkout:

| Ref | Evidence |
| --- | --- |
| S1 | [ProjectOnboarding](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift): finish phase gate around 602, exclusions replacement around 622, path-derived ID around 911. |
| S2 | [OnboardingView](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/Projects/OnboardingView.swift): Finish gate around 423; resumed state around 623. [OnboardingAcceptanceTests](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarTests/OnboardingAcceptanceTests.swift): manual phase setup around 529–575. |
| S3 | [DeliveryStore](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Store/DeliveryStore.swift): connection/availability 63–108; transaction/audit 169–206. [StoreMigrations](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Store/StoreMigrations.swift): base identity/placement 935 onward; newer goal/task relationships. |
| S4 | [AppRoute](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/Navigation/AppRoute.swift#L3), [AppModel](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/App/AppModel.swift#L813), [DashboardProjection](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/Projects/DashboardProjection.swift#L96): incomplete route state, active dependency scope, all-phase loading. |
| S5 | [ProjectActivityProjection](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/Activity/ProjectActivityProjection.swift#L58): event union and current-state decoration; #18/#19 document reported freshness/recovery gaps. |
| S6 | [SettingsView](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar/Notifications/SettingsView.swift#L273), [test scheme](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme), [prior installed repair evidence](../evidence/2026-09-02-rr-r10-task-11b-installed-workflow-repair.md). |
| S7 | [AgentQuery](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Documentation/DocumentationOperations.swift#L50), [AgentCommand](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/AgentBridge/AgentCommand.swift#L40), [dispatcher attribution](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift#L71). |
| S8 | [CodexPluginLifecycle](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift), [observer](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Codex/CodexObserver.swift), [runtime models](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarCore/Codex/CodexRuntimeModels.swift#L87), [helper entitlements](https://github.com/joeroberts/release-radar/blob/fcb432bf2c6f5e5bab63418adb9b6ec647e1baef/ReleaseRadarPluginLifecycleHelper/ReleaseRadarPluginLifecycleHelper.entitlements#L7). |
