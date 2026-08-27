# RR-04 implementation report — folder-backed onboarding

## Scope

Implemented only the RR-04 onboarding slice: native folder selection, bookmark
storage, canonical discovery, worktree authorization, persisted exclusions and
review items. No board, live observer, importer, or notification sender was
added.

## TDD evidence

- RED: `/tmp/rr04-red.log` — onboarding contracts did not exist.
- RED: `/tmp/rr04-red-authorize.log` — no separate authorization operation
  existed for an external worktree.
- GREEN: `/tmp/rr04-green.log` — focused acceptance coverage passed after the
  minimal implementation.

## Required fix round 1

- RED: focused `OnboardingAcceptanceTests` against
  `/tmp/rr04-fix1-red` failed before implementation because the new ownership,
  request/wait, and scoped-bookmark contracts were absent.
- The owner can no longer enter a phase ID or name, and onboarding no longer
  constructs an `AgentCommandDispatcher`. It records an app-owned
  `onboarding_phase_request` Needs Review item, polls for a persisted phase,
  and enables Finish only after an actual typed agent bridge upsert.
- Bookmark resolution and security-scoped access are injected together. Failed
  or stale persisted bookmarks are marked stale and excluded from discovery;
  there is no raw stored-path fallback.
- Root/worktree ownership is checked before any project/root/bookmark write in
  the same audited transaction. Finish reconciles the editable onboarding
  exclusion set before adding unmatched-task reviews.

## Verification

- `OnboardingAcceptanceTests` plus the directly affected
  `StoreAcceptanceTests`: 17 passed, 0 failures/skips
  (`/tmp/rr04-final-tests.log`).
- Normal signed Debug app build passed (`/tmp/rr04-final-build.log`).
- Fix round focused `OnboardingAcceptanceTests` plus `StoreAcceptanceTests`:
  19 passed, 0 failures/skips (`/tmp/rr04-fix1-final`).
- Fix round normal signed Debug build passed (`/tmp/rr04-fix1-final-build`),
  followed by `codesign --verify --deep --strict --verbose=2`.

## Review state

Implementation is complete but not accepted or released. Fresh independent
code, QA, architecture, and security/privacy review remain required.

Implementation commit: `0012372` (`feat: onboard folder-backed projects`).

Fix-round implementation commit: `af5dd0a` (`fix: harden project onboarding boundaries`).

## Required fix round 2

- RED: the focused denied-scope acceptance test at `/tmp/rr04-fix2-red`
  could not construct an injected resolver/scope adapter or assert the missing
  authorization error.
- `ProjectBookmarkStore.withSecurityScopedAccess` now throws
  `ProjectBookmarkError.securityScopeAccessDenied` when security scope cannot
  start; it invokes neither its body nor `stopAccessing` on that path.
- GREEN: an injected non-stale resolved bookmark with denied scope start proves
  one denied start, zero stops, zero discovery calls, and zero persisted project
  roots (`/tmp/rr04-fix2-green`).
- Final focused Onboarding + Store suite: 20 passed, 0 failures/skips
  (`/tmp/rr04-fix2-final`); signed Debug build and strict signature verification
  passed (`/tmp/rr04-fix2-final-build`).

Fix-round implementation commit: `f545034` (`fix: reject denied bookmark scope access`).
