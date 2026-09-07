# Usable project lifecycle delivery

Date: 2026-09-06. Status: active controlling brief; current authorization and
programme sequencing remain in `docs/delivery/progress.md`.

## Objective and outcome

Deliver C1, C2, C3 and the first C12/Help/RDS slice as one usable macOS journey:
save a folder-backed project, see it with zero phases, resume or edit its saved
metadata, complete the real copied documentation handoff, recover exact-folder
access, and understand simultaneous store/access/catalog/plugin/observer health.
The journey must survive relaunch and must never turn an observation, copy action,
folder grant, seed choice, binding, or catalog acceptance into another action.

## Scope and exclusions

Add opaque IDs for new projects plus a separate local registration and request
generation while preserving every legacy project ID. Persist honest setup state,
name and task exclusions; unavailable observation must not erase exclusions.
Finish acknowledges saved choices and permits zero phases while leaving incomplete
documentation visibly actionable. Rename and exclusion editing target the exact
saved registration and cannot alter roots, apply a seed, create delivery state, or
reinitialize the project.

Provide previewed copied handoffs for blank and existing-document repositories.
The preview names the exact root, project ID, registration and request generation;
Copy reports accessible success/failure and never dispatches. Repository bootstrap
or repair remains a separately authorized repository action. Check is read-only.
Binding, catalog acceptance and audited handoff remain separate explicit app-owned
actions using existing typed contracts, exact identity and replay-safe requests.

Expose exact same-folder reauthorization directly from access failures even when
the catalog is invalid, while keeping legacy first-root attachment and managed
relocation distinct. Consolidate store, folder access, documentation, plugin and
observer health with exact targets, check times, simultaneous failures, read-only
refresh and registration-scoped late-result rejection; health remains reachable
when the delivery store is unavailable. Add contextual Help for these flows and
use existing RekonDesignSystem components, tokens and fixed appearance in the app
target at reviewed revision `d0932aa6b6c21f420ea197a9cc7b14254c23695a` through
a reproducible revision-pinned package resolution.

Do not add product metadata fields, reinterpret task exclusions as document-scan
filters, change light/dark support, edit RekonDesignSystem, create phases or
catalogs in status checks, invent test-only handoff steps, or implement archive,
removal tombstones, full backup, cloud publication/outbox, complete navigation
history, broad C8 watching, portable import/export, or later planning outcomes.
Do not modify `docs/delivery/progress.md`, Codex configuration/rules/hooks, owner
SQLite/Keychain data, the installed app, the canonical checkout, or retained stash.

## Dependencies and future consumers

Use the accepted D1 and D2/D8 decisions in the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), and
the [dashboard design](../../../design/agent-driven-delivery-dashboard-design.md).
Preserve app-owned delivery authority, repository-owned documents, explicit root
capabilities, accepted catalog identity, the five lanes, and observer degradation.

Registration identity and generations are future inputs to archive/remove/re-add,
backup restore, portable import, observations and external callbacks. Setup and
health facts feed later C8/C9 freshness, C4-C7 recovery, P15-P19 navigation and
evidence, and optional integrations without implementing those features here.
Migration preserves legacy IDs/relationships and supplies compatible registration
state without claiming prior setup or document acceptance. Recovery renews only
capabilities; it never rewrites identity or silently repairs repository content.

## Assignment and ownership

- Delivery owner: task `01a078df-3ce2-7183-96a9-0cf10aca159c`,
  `gpt-5.6-sol` / High, on branch `codex/usable-project-lifecycle` from baseline
  `3949f0f29aae64ba8186d5f163e945a702a6496b` (which contains PR #22 merge
  `c22a32ca4eb310973ba9cce5eb0df472d2262bfb` and original merged baseline
  `acfaeeddd7159c44e9cc2ecb62de6b12024b1f61`). Sol High is justified by registration
  compatibility, bootstrap authority and recovery. Astra High is the ceiling only
  for a named unresolved authority/compatibility problem; Ultra and Xhigh/Max are
  prohibited.
- This task owns directly relevant Core/app code, existing tests, shipped lifecycle
  guidance, affected accepted product design, this brief, and required catalog/index
  metadata. The parent orchestrator exclusively owns `docs/delivery/progress.md`,
  programme integration and task lifecycle. No shared application state is owned.
- The parent commissions one fresh independent reviewer for the exact candidate,
  combining architecture/security/QA/UX risks. This task does not self-review or
  create an additional review chain.

## Material risks and test strategy

Material risks are legacy identity loss, path/registration reuse, stale callbacks,
partial metadata edits, implicit repository/app mutations, lost exclusions,
authorization or root confusion, false health freshness, inaccessible recovery,
and static UI presented as a complete workflow.

Use test-first changes in the existing XCTest suites and synthetic roots/stores.
Cover schema migration and legacy preservation; opaque new IDs; distinct
registration/generation identity; ambiguous legacy and stale request rejection;
save/resume/relaunch and cancellation/error preservation; name/exclusion edits with
unavailable observation; zero-phase Finish; blank/existing-document prompt preview
and actual copy success/failure; restart, wrong identity, invalid catalog, binding
and acceptance boundaries; exact-folder reauthorization versus first-root and
relocation; mixed health, unavailable store, check times and stale results; and no
implicit writes, phases, seed application, binding, acceptance or audit.

Exercise the immediate UI-to-Core boundary with the repository's native synthetic
host. Compare the compatible calm card/status language from accepted mockups and
the actual RDS-backed UI at compact and wide sizes; verify keyboard actions,
accessibility labels/announcements, focus recovery and recoverable errors. Build the
app and bundled documentation/agent tools from the same candidate. Installed folder
picker, VoiceOver and authorization-dialog acceptance remain explicitly unclaimed
until separately authorized.

## Acceptance criteria

1. A newly saved folder-backed project has opaque domain/registration identity,
   is visible with zero phases, and resumes after store reopen with exact saved
   name, exclusions, roots and setup/documentation facts.
2. Finish never creates a phase or certifies documentation. Outstanding bootstrap,
   binding, acceptance or audited-handoff work remains visible and actionable.
3. Editing name/exclusions is an exact-registration, atomic metadata action;
   cancel, invalid input, unavailable observation, wrong identity and write failure
   preserve prior data and all unrelated state.
4. The app previews and copies the real exact-root/project bootstrap or repair
   handoff with accessible success/failure. Check is read-only; separately explicit
   typed binding/acceptance/audit actions are identity-checked and replay-safe.
5. Access errors offer exact same-folder reauthorization before catalog repair;
   invalid documents remain reported afterward. First-root attachment and relocation
   retain their own labels, confirmations and rules.
6. One reachable health presentation shows store/access/catalog/plugin/observer
   outcomes together, including simultaneous failure, exact targets and check times;
   stale or superseded results cannot replace a newer registration observation.
7. Contextual Help explains the complete journey and boundaries. Relevant app UI
   uses the pinned RDS revision without Core dependency or appearance changes and
   passes focused native tests/build plus compact/wide accessibility inspection.

## Candidate verification and remaining acceptance

Corrected product checkpoint `f98bf14782fe17f22d9c3b9ef736ff7ba9ca7bcb`
closes the six Required findings from the first independent review: exact-folder
health recovery, scoped catalog validation, conservative v14 migration, complete
bootstrap/upgrade/repair prompt routing, truthful health freshness, and atomic
registration-generation validation. After integrating the parent ledger through
`6e79849`, merge checkpoint `f63b628` passes 214/214 focused onboarding,
managed-documentation, app-route, native-rendering, compatibility, installation-
resource and store tests with zero skips. The initial candidate's wider full-suite
run remains 547/548; its sole failure was the pre-existing controlled-transport
acceptance that requires an already enabled bridge, and an isolated rerun reported
that exact disabled-bridge condition. The resolved RekonDesignSystem revision is
`d0932aa6b6c21f420ea197a9cc7b14254c23695a`.

The native lifecycle overview was accessibility-traversed and rendered at 1100 and
620 points. Both PNGs were visually inspected against the applicable onboarding
and settings mockups for the fixed dark appearance, calm RDS card language,
readability, action hierarchy and compact/wide composition. The assertions and
attachments remain temporary, non-controlling evidence in
`/tmp/release-radar-lifecycle-candidate-focused.xcresult`; the exported lifecycle
PNGs are
`/tmp/release-radar-lifecycle-candidate-render-attachments/26C6F41C-0472-4485-923B-DBFB92438369.png`
and
`/tmp/release-radar-lifecycle-candidate-render-attachments/51A496EE-E8C8-45DB-976F-16670D11BFD0.png`.
Other remaining temporary paths are `/tmp/release-radar-lifecycle-derived`,
`/tmp/release-radar-lifecycle-full2.xcresult` and
`/tmp/release-radar-lifecycle-transport.xcresult`. Corrected post-merge source and
native evidence is in `/tmp/release-radar-lifecycle-corrected-post-merge.xcresult`;
no cleanup is authorized.

Installed folder-picker, authorization-dialog and VoiceOver acceptance remains
unclaimed. If separately authorized, build the reviewed revision with the documented
Xcode scheme and use only an owner-designated disposable test location, empty app
container and disposable repository. Exercise copy, finish, relaunch,
rename/exclusions, documentation preview/confirmation, same-folder reauthorization,
simultaneous health failures and keyboard/VoiceOver recovery. A separate macOS
account is optional, not a prerequisite. Do not use owner application state or
install over the owner's app for that check.

## Delivery endpoint

Update affected shipped guidance and accepted product design with the delivered
semantics, maintain this mutable brief and catalog/generated indexes without a
checksum, run the native documentation check, and create scoped local implementation
commits. Branch push and PR creation are authorized. Merge requires a fresh owner
approval and is not performed here. Installation, app launch against owner state,
binding/catalog acceptance, external publication and cleanup are not authorized.
Return the exact candidate revision, changed files/behavior, direct test and runtime
evidence, reproducible build or installation procedure if needed, remaining risks,
and any concrete separate authorization required for installed acceptance.

## Owner-authorized plugin registration recovery correction — 2026-09-07

The owner authorized a bounded correction after installed 0.1.7 acceptance exposed
a stale `SMAppService` registration: the main app ran from
`/Applications/ReleaseRadar.app`, while the lifecycle helper still executed from an
older review bundle and therefore rejected the current marketplace as foreign.

The correction is limited to `CodexPluginLifecycleClient` and focused transport
tests. Before any install, update, reinstall, or removal command, the client probes
the helper. If the enabled helper is unavailable or reports a marketplace conflict,
the client invalidates its connection, unregisters and re-registers only the
packaged Release Radar lifecycle agent, probes once more, and proceeds only after a
successful reply. It never replays a mutating plugin command after an uncertain
result. A persistent genuine conflict remains a failure. Approval-required and
unknown service states fail closed; no broad Login Items reset, unrelated service
change, direct Codex configuration edit, or SQLite edit is permitted.

Focused tests must first fail on the reproduced stale-enabled-service sequence,
then prove one bounded rebind, a successful post-rebind probe before the requested
mutation, no mutation for a persistent conflict, and no retry after an uncertain
mutation result. Verification includes the focused XCTest target, the relevant
plugin lifecycle suite, a signed Release build, installed helper executable
readback from `/Applications/ReleaseRadar.app`, and an application-driven plugin
install/update with Codex reporting the shipped version. The parent commissions
one fresh independent reviewer covering code, service-registration security, and
the installed recovery behavior; only Required findings block.

For this correction, the owner explicitly authorized replacing the installed app
with the new signed candidate, launching it against the existing owner state,
resetting only the stale Release Radar lifecycle service registration, and retrying
the app-owned plugin operation. The existing authorization for scoped commits,
branch push, and PR update remains; merge, broad system-service changes, owner-data
reset, direct plugin/configuration mutation outside the app operation, publication,
and cleanup remain unauthorized.

## Owner-authorized UI correction checkpoint — 2026-09-07

The owner authorized a same-outcome correction pass for the running macOS app. It
is limited to blending the native titlebar into the RDS background, clarifying the
sidebar collapse control, centering the truly empty Needs Review state without a
zero badge or empty list column, making Settings panels responsive, repairing alert
rule spacing and hit targets, clarifying Application Health status and recovery
actions, and replacing neutral gray card/control/separator boundaries with subdued
use of authoritative RDS public APIs rather than an application-local style layer.
Native traffic-light controls, window behavior,
semantic warning/error colors, current persisted behavior and the General tab's
existing content remain unchanged.

Focused tests cover native window capabilities, responsive widths, empty-review
suppression, alert-rule accessibility sizes, health recovery routing, and compact
and wide native rendering. Completion also requires a signed build, visual and
accessibility inspection of the installed app at ordinary and compact sizes, plugin
lifecycle readback after replacement, and one fresh independent UX/code review.
The existing installation and launch authorization applies to this corrected
candidate; merge, external publication, owner-data reset, direct SQLite/Codex
configuration mutation and cleanup remain unauthorized.
