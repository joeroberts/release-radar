# RR-05 implementation report — Codex observation feasibility

## Outcome

The supported shared live-attachment gate did not pass. Release Radar therefore
implements only the approved explicit unavailable/cached-stale boundary. It does
not contain an app-server client, observation helper, or private Codex-state
reader.

## Bounded feasibility evidence

- `codex --version` reported `codex-cli 0.147.0`.
- The official Codex manual and `codex app-server --help` describe transports
  selected when an app-server process starts. The default is stdio; an external
  named listener requires an explicit listen configuration.
- The running Codex desktop process starts `app-server` without an explicit
  listener. Read-only process/listener inspection found parent-owned pipes and
  no supported named Unix or TCP listener for an authenticated sandboxed
  Release Radar client.
- A separately launched app-server process was excluded as proof because it
  would not establish access to the currently running desktop task.
- No Codex database, rollout/session file, terminal, log, UI, or undocumented
  IPC content was read. No Codex task was mutated.

The stop rule was applied after the official transport review and running
process/listener review produced the same blocking result. No third attachment
approach or speculative protocol client was attempted.

## Implemented boundary

- Stable `CodexObserver` snapshot/event contract.
- Normalized runtime snapshot, freshness, thread, goal, waiting, completion,
  and goal-clear models.
- `UnavailableCodexObserver`, which reports `unavailable` without cached state
  and always downgrades injected cached state to `stale`.
- App state loads the observer result on dashboard entry and fails closed to
  explicit unavailable state if observation throws.
- Observation has no store mutation capability and cannot move a ticket lane.

Implementation commit: `ae5fd63` (`feat: define unavailable Codex observation`).

## TDD and verification

- RED: `/tmp/rr05-degraded-red.log` — runtime models and observer did not exist.
- GREEN: `/tmp/rr05-focused-green.log` — 4 observer acceptance cases and 1 app
  state-integration case passed with 0 failures/skips.
- Regression: `/tmp/rr05-projection-regression.log` — 5 dashboard projection
  cases passed with 0 failures/skips.
- Signed package: `./script/build_and_run.sh --verify` completed successfully at
  `/tmp/rr05-build-run.log`; `codesign --verify --deep --strict --verbose=2`
  passed at `/tmp/rr05-codesign.log`; `git diff --check` passed.
- The runtime fixture covers Active, Paused, Blocked, Awaiting input,
  Completed/Ready for review, active flags, active goal, and goal clearing.
- A store-backed boundary case proves an observer snapshot cannot change the
  formal RR-05 lane.

## Review state

Implementation is not accepted or released. Fresh independent Code Reviewer,
QA, Architect, and Security/privacy review remain required. RR-07 remains
closed until this explicit degraded outcome is accepted.

## Required fix round 1

Initial QA identified two Required cache-boundary findings.

- RED: `/tmp/rr05-fix1-red.log` failed because no
  `CodexObservationScope` or scoped observer initializer existed.
- Unsupported cached schema versions now produce a current-schema explicit
  unavailable/empty snapshot and can never become stale.
- Compatible cache requires an injected canonical selected project root,
  separately authorized worktree roots, and excluded thread IDs. Without that
  scope, cached state is unavailable and empty.
- Scope filtering resolves symlinks, compares path components, and accepts only
  existing directories at the selected root, below it, or below an authorized
  worktree. Sibling-prefix, outside, nonexistent, symlink-escape, and excluded
  threads are rejected without reading directory contents.
- GREEN: `/tmp/rr05-fix1-final-observer.log` passed 7/7 focused observer cases.
- Final affected verification: `/tmp/rr05-fix1-final-tests.log` passed 16/16
  observer, dashboard-projection, and app-route cases.
- Signed package: `/tmp/rr05-fix1-build-run.log` completed the configured build
  and launch verification; `/tmp/rr05-fix1-codesign.log` passed strict deep
  codesign verification; `git diff --check` passed.

Fix-round implementation commit: `c94135f` (`fix: scope cached Codex observations`).

RR-05 remains unaccepted pending fresh independent re-review. RR-07 remains
closed.
