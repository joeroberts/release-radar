# P6 Manage Project — Task01: immediate identity-bound opening

## Objective and outcome

Implement `rr-p6-manage-project-task-01`: selecting **Manage Project** from an
active project's Overview opens a management surface immediately. The surface
identifies the exact selected project and registration while its existing
management sections load independently. A failure stays in the affected section
and offers that section's local retry/recovery; it must not replace the Overview
or block unrelated sections.

## Scope and exclusions

In scope is the Overview entry/state, the Manage Project surface and its loading
states, identity propagation/validation, section-local errors and retries, and
focused native XCTest coverage. Preserve the existing settings save and execution
actions and their authorization/error contracts.

Task02 is explicitly excluded: do not relocate documentation activation, shared
execution, repository-folder access, Project Health, project evidence, or other
Overview panels. Archive/Remove relocation and separate navigation/Help changes
are also excluded. Do not change persistence, permissions, registration rules,
public APIs, task definitions, project lifecycle behavior, or Release Radar
application state.

## Dependencies and boundaries

- Baseline: `7305f277`; use the current source, not an older candidate.
- Design: [Phase 6 workspace toolbar proposal](../../design/phase6-workspace-toolbar-proposal.md), including the wide and compact toolbar mockups. Its selected Manage Project behavior is controlling for this task.
- Architecture: [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md) and existing `ProjectRegistration` identity semantics.
- Current entry: `ProjectOverviewView` invokes `loadProjectSettings` before it presents the settings sheet; `SidebarView` supplies the selected active project's `projectID`.

The management surface captures the selected `ProjectRegistration` at opening.
Every asynchronous result must match that captured registration (project ID,
registration ID, and request generation) before it is displayed or used by an
action. A stale/mismatched or unavailable registration is an actionable local
state, not permission to show a different project's information or perform a
write. Existing callbacks retain their typed, registration-scoped authorization.

## Material risks

- Delayed sheet presentation hides the selected-project context during slow or
  failed loads.
- A stale completion could populate a replacement registration.
- One failing loader could suppress usable management controls or turn a local
  error into an unrelated Project Health error.
- Retrying could unintentionally rerun another section or mutate project state.

## Test strategy and acceptance criteria

Add the following focused XCTest cases before production changes. They are
expected to be RED against baseline `7305f277`.

1. `testManageProjectOpensImmediatelyWithSelectedRegistrationAndIndependentSections`
   presses `project-manage` while the settings loader remains suspended, then
   requires visible `manage-project-panel` and `manage-project-identity`. The
   identity must contain the selected project ID, registration ID and request
   generation. It also requires the independently available section identifier
   `manage-project-section-execution` while `manage-project-section-settings`
   is loading.
2. `testManageProjectSettingsFailureIsLocalAndRetryLoadsOnlySettings`
   makes the settings load fail once. It requires
   `manage-project-section-settings-error` and
   `manage-project-section-settings-retry`, keeps
   `manage-project-section-execution` available, presses the retry, and asserts
   that only the settings loader is invoked again and its successful content is
   shown.
3. `testManageProjectRejectsStaleSettingsRegistration`
   returns a `ProjectSettingsSnapshot` for a different registration. It requires
   `manage-project-section-settings-error` and the local retry, does not show
   the mismatched settings as editable content, and does not call save or any
   execution mutation.
4. Extend the existing native rendering coverage at 1100 and 620 points to show
   the selected identity and local loading/error presentation accessibly. The
   pre-existing `project-manage` accessibility identifier remains available.

Acceptance is met only when the surface opens before any section completes;
the exact selected identity remains visible; each owned section loads, fails and
retries without blocking another; stale results are rejected locally; existing
active/archived/removed access boundaries and authorization behavior remain
unchanged; and focused tests pass. Compare the implemented wide and compact
surface with the cited reference; record any necessary deviation in the mutable
design document.

## Reviews and endpoint

One independent UX/recovery review is required because this is a user-facing
loading and recovery journey. It must assess immediate identity visibility,
independent loading, local retry, accessible error recovery, and stale-selection
handling. Build Agent `01a0c061-578a-7e22-8ba3-77348fd6dcac` exclusively runs
compilation/tests and makes Git commits. Main owns the progress ledger,
documentation/index validation, and brief commit. No release, installation,
push, publication, application-state operation, or Release Radar mutation is
authorized by this task.
