# Documentation lifecycle — GitHub #118

- Plan, acceptance criteria and results: [GitHub #118](https://github.com/joeroberts/release-radar/issues/118).
- Root: /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar.
- Outcome: remove obsolete documentation and enforce agreed retention through Git hooks.
- Authorization: Task01 assessment plus the owner's subsequent documentation
  cleanup directions. The September 22 task-brief pass extracts still-valid missing
  requirements/decisions and removes inactive briefs with reference/catalog repair.
  New retention enforcement, hooks, product changes, push, PR, merge and release
  remain outside this cleanup authorization.
- Workflow: ordinary Codex tasks, Git worktrees, native checks and `gh`.
  Follow [AGENTS.md](../../../../AGENTS.md). GitHub holds current work and results.
- This project has been removed from RR tracking. No RR registration, managed
  workers, shared-execution skills, plugin compatibility, catalog acceptance,
  phase transitions or app-state synchronization are required or in scope.
- The existing brief path and task labels preserve discussion continuity only.
  Historical setup receipts and prior RR blockers do not govern this work.

## Task01

Review every brief for embedded architectural decisions. Identify decisions still
applicable and not already covered by accepted ADRs; propose their ADR destinations.
Discard superseded decisions and repair references. The owner authorized extraction
and deletion of inactive briefs; this current #118 brief remains while the work is
active and has no permanent retention exception. No issue/merge-proof gate is
required for this authorized cleanup.

Establish keep, extract-then-delete or delete dispositions for other documentation; exact retention rules;
actual file/reference/ADR/manifest/test dependencies; related-issue dispositions;
and mechanically enforceable hook checks using GitHub issue status and verified
PR merge status. Define exact issue/PR associations and unavailable-status behavior.
Do not preserve or reconcile valueless material. No mandatory ledger edits.
Assess proposed 100-line/12-KiB limits only if a local progress note is retained.

Evaluate #55, #71, #74, #87, #101 and retained Guided Setup/Plan Reconstruction
requirements for actual overlap or supersession. Unrelated RR features, including
#87 and Guided Setup, are not execution prerequisites. No related issue closure or
new product work is implied. Proposals need duplicate/conflict checks; selected
studies belong in GitHub Wiki, with destination verification before later deletion.

Keep accepted ADR decision text intact; repair only their citation destinations
where the owner-authorized deletion removes a source. Assess catalog/index metadata and native checks
as repository dependencies; do not restore app acceptance requirements or weaken
product validators. Preserve Git history and unrelated files/configuration.

## Sequence, checks and endpoint

1. Task01: concise assessment and unresolved decisions in #118, with one independent
   review. Do not claim completion or owner acceptance without evidence.
2. Task02, after authorization: cleanup/relocation and affected references,
   retained metadata/manifests and test fixtures.
3. Task03, after authorization: one small checker shared by pre-commit/pre-push,
   tested against staged/outgoing content and installed without replacing other hooks.
4. Task04, after authorization: independent review and permitted delivery.
   This brief is included in the cleanup; no special retention exemption.

Risks: losing useful knowledge, broken references/tests, overwriting hooks and
unreliable GitHub lifecycle associations. Direct checks are proportional native
checks and targeted tests for the changed property; only Required review findings
block. Record results and limitations in #118/the PR, not new process documents.
