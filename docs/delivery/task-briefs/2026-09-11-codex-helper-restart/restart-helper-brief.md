# Codex lifecycle helper restart

Date: 2026-09-11. Status: owner-authorized bounded implementation in progress.
The current delivery state remains in `docs/delivery/progress.md`; the parent
delivery task owns that ledger.

## Shared execution context

- **Standard:** `shared-execution/1`; the source and installed plugin are version
  `0.1.9` with the four-file inventory including `skills/shared-execution/SKILL.md`.
- **Root:** `/Users/jroberts/.codex/worktrees/0745/release_radar`.
- **Outcome:** Add a Settings > Connections action that restarts/re-registers the
  lifecycle helper from the currently installed Release Radar application, then
  refreshes and presents plugin status with accessible progress, success, and
  actionable failure.
- **Scope:** Own the existing lifecycle manager/client/coordinator, Settings model
  and view, focused tests, shared Help, this brief, catalog metadata, and generated
  documentation indexes. Preserve plugin bytes, Codex configuration, project data,
  receipts except for existing observation behavior, and all unrelated work.
- **Authority:** Owner kickoff in the delivery task; accepted
  `docs/architecture/ADR-002-codex-plugin-lifecycle.md`,
  `docs/design/release-radar-codex-plugin-lifecycle-design.md`,
  `docs/design/mockups/settings.png`, and
  `docs/architecture/ADR-007-proportional-delivery-validation.md`; baseline
  `e55ffd7f0bef7af7e6fbe7c0c1f2d6454147ca04`.
- **Endpoint:** Focused source, tests, Help/manual acceptance guidance,
  documentation check, one independent review, and scoped local commits. Push,
  PR, merge, DMG creation, installation, app launch, owner-state mutation, live
  service registration, and Release Radar application mutations are excluded.
- **Direct checks:** Focused lifecycle transport/coordinator/AppModel tests prove
  forced rebind, fresh status, permission/failure behavior, serialization, and no
  install/remove/reinstall operation. Existing rendering tests use temporary
  synthetic state at wide and compact widths to prove layout, accessibility,
  progress, success, and failure. The Xcode build and documentation tool check
  prove compilation and repository documentation consistency.
- **Review:** One fresh independent reviewer covers the service lifecycle/security
  boundary and the UI recovery behavior. Required findings block; Optional and Out
  of scope findings do not expand this task.

## Design and constraints

The app-side client exposes a restart operation without adding a fifth XPC method.
It invalidates the existing connection, unregisters the fixed `SMAppService` when
enabled, registers the same helper declared by the currently installed app, and
performs one fresh status call. It never invokes install, remove, or reinstall and
accepts no caller-selected path, identity, command, or arguments.

The existing AppModel operation state serializes the owner action with every other
plugin lifecycle operation. Settings places **Restart helper** beside the current
plugin actions. While it runs, the status announces **Restarting lifecycle helper**
and no lifecycle action is available. Success says the helper restarted and plugin
status refreshed. Permission denial directs the owner to Login Items; other failures
retain the existing privacy-bounded recovery copy and allow retry.

The explicit restart addresses a stale enabled helper whose old code can validly
return `needsRepair(.integrityInvalid)` for the newer four-file package. Existing
automatic recovery remains limited to unavailable/conflicting replies; integrity
validation is not weakened and a plugin reinstall is not used as a service restart.

## Test strategy and acceptance criteria

Use test-first changes in existing suites. The failing tests must establish:

1. the client unregisters and registers an enabled service, then issues exactly one
   status operation and returns that validated result;
2. registration approval/failure is surfaced without a remote or plugin mutation;
3. the coordinator converts the fresh result through the existing receipt/state
   rules without recording an installation change;
4. AppModel publishes progress, success, and actionable failure, refreshes dependent
   documentation observations, and rejects a second lifecycle action while busy;
5. Settings exposes one accessible **Restart helper** control and responsive
   synthetic rendering at wide and compact widths; and
6. the shared Help explains when to restart the helper, what it preserves, and how
   to recover from Login Items approval or a repeated failure.

Direct runtime testing in this task remains isolated and synthetic. A later manual
owner acceptance run, only after a separately authorized signed installation, should
open Settings > Connections, activate **Restart helper**, observe the progress and
success announcement, confirm the current plugin returns to **Installed**, and start
a fresh Codex task to confirm the existing workflow remains callable. If macOS asks
for approval, the owner should allow the Release Radar helper in Login Items and retry.
The run must confirm the installed plugin files and owner projects are unchanged.

## Assignment and material risks

The delivery owner uses Sol High on branch `codex/restart-plugin-helper` in the exact
root above and owns the complete bounded implementation plus local commits. Astra
High is the ceiling only for a named unresolved service-boundary problem; Ultra is
prohibited. The parent task coordinates the independent reviewer and owns the
progress ledger.

Material risks are restarting the wrong service, accidentally mutating plugin/Codex
state, racing another lifecycle operation, losing actionable permission recovery,
or falsely claiming signed installed behavior from synthetic tests. The fixed
`SMAppService` object, unchanged four-method XPC contract, operation guard, focused
call-sequence assertions, and explicit runtime limitation address those risks. No
persistence migration, compatibility change, or destructive recovery is involved.
