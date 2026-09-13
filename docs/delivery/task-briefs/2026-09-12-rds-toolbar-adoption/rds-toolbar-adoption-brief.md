# RDS toolbar consumer adoption

Status: completed; historical and non-authoritative. Delivery is integrated into
`main`; current authorization lives in [progress](../../progress.md#current-authorization).

Original assignment status (historical): owner-authorized bounded implementation. This brief records the already
approved toolbar decisions; it does not reopen Phase 6 planning.

## Objective and outcome

Adopt merged RekonDesignSystem revision
`3c2626102a2e97dd93f31fbc62b733085d6700ec` and implement the owner-selected
persistent workspace toolbar and compact sidebar in Release Radar. The toolbar
remains present across destinations, submits one app-owned search draft through
the existing search/history boundary, and saves the visible definition through a
naming popover without executing or adding history.

## Scope and exclusions

Use `RekonToolbar`, `RekonSearchField` prompt/submit support and
`RekonBorderlessIconButtonStyle`; do not create app-local visual substitutes.
Move the sidebar toggle and Back/Forward to the toolbar, expose wide text and
compact bookmark Save query actions, and keep Help, Settings and Notifications
directly accessible. Remove those four duplicate sidebar routes, retain Projects,
Goals, Needs Review and project routes, use the real borderless app logo, reserve a
fixed documentation-checking footer, and remove “Persisted locally.” Preserve the
approved palette, scope/identity/authorization, stale and unsupported state,
saved-query persistence, exact-record navigation and recovery behavior. Update
only affected Help guidance.

Phase 6F metrics, Manage Project relocation, Archive/Remove relocation, guided
shared-execution adoption, Pursuit reconstruction, Phase 7, historical RDS tags,
packaging, installation and owner/live application state are excluded. No SQLite,
catalog-acceptance, plugin, helper, push, PR or merge mutation is authorized.

## Dependencies and boundaries

Baseline is committed `83f3bb89d4de5cabd29ebff297ea95fa260c1ed9` on
`codex/rds-toolbar-adoption`; the assigned design branch is not advertised by
`origin`, while the exact local commit is available. RDS PR #7 is merged at the
revision above. The controlling product reference is
[the Phase 6 toolbar proposal](../../../design/phase6-workspace-toolbar-proposal.md)
and its linked wide and compact images. RDS owns reusable visual composition;
Release Radar owns routes, drafts, actions, badges, breakpoints and window policy.
No persistence schema, external integration or compatibility migration changes.

## Material risks and test strategy

Material risks are duplicate search execution, draft/result coupling, lost source
history, saving the wrong definition, inaccessible compact controls, and toolbar
or sidebar overflow. Develop behavior test-first. Focus regression coverage on
draft-versus-results state, one-shot submission from Return and magnifier, source
route restoration, save-without-search/history, route lists and responsive layout.
Run the relevant XCTest selection and app build. Render the actual isolated native
window at wide and compact sizes, inspect keyboard/focus/accessibility and
unsupported/authorization recovery, and compare repository captures with both
approved references. Use only disposable data and existing fixtures.

## Acceptance criteria and reviews

The exact RDS pin resolves; the persistent toolbar and compact/wide sidebar match
the approved behavior; toolbar search and save journeys preserve existing
authority, persistence and recovery; duplicate sidebar entries and shifting footer
content are gone; focused tests, build and documentation check pass; useful native
captures are stored under `docs/delivery/evidence/`; and no installed or owner state
is touched. One fresh independent reviewer covers code/integration plus
UX/accessibility. Only Required findings block.

## Assignment and endpoint

Delivery owner is this Sol/high task, parent Master Delivery Thread
`01a07e75-b254-72a1-be2a-3e97ac23baeb`. It owns source, tests, this brief,
applicable catalog/index documentation, evidence and the concise progress entry in
this worktree. Endpoint is scoped local commit(s), direct checks and reviewable
render evidence; parent creates the independent review. Model ceiling is
Astra/high only for a named unresolved boundary problem; Ultra is prohibited.
