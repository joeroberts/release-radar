# Discover supported Codex rules and hooks

## Assignment brief — 2026-09-07

Status: authorized bounded discovery; findings pending. This artifact records a
proposal, not accepted architecture or implementation.

Determine actual supported command restrictions and mechanical follow-through for relevant tests, documentation, commits and authorized PR endpoints. Produce the smallest justified configuration proposal and an isolated test plan/proof where feasible; distinguish supported tool coverage from gaps.

Use the OpenAI Docs skill, current official rules/hooks sources and bounded installed-runtime inspection. Preserve STOP, approval waits, legitimate blockers, task ownership and existing authorization. Do not modify active/global/repository governing instructions, enabled rules/hooks or security configuration. No automatic publishing, approval engine, new task database, continuation loop, universal-security claim or undocumented transcript parsing. I9 discovery does not gate recovery source delivery.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Retain all 40 capabilities and accepted versus proposed distinctions. RDS appearance
is unchanged. This discovery does not reopen completed lifecycle work or gate C4.

Model/effort: gpt-5.6-terra / medium; ceiling: Sol High only for a named runtime/compatibility question; Ultra prohibited. Assigned baseline is
`c4ddffb` plus the committed discovery briefs/catalog preparation on
`codex/recovery-orchestration`; the dispatch supplies its exact revision. Use a fresh
worktree and named `codex/discovery-rules-hooks` branch with upstream. Own only this
artifact. The orchestrator owns progress, shared plan/catalog/index integration.
Do not overwrite another worker's files or edit the canonical checkout.

Verification: cite current primary sources supporting conclusions; distinguish
verified local capability, documentary evidence, hypothesis and unavailable proof.
Use only bounded isolated tests justified by the question. Report compatibility,
privacy/recovery risks and any material unresolved owner choice with recommendation.
One fresh independent substantive reviewer covers actual proposal risks; only
Required findings block. No review-of-review or implementation approval implied.

Endpoint: coherent findings in this artifact, scoped commit, branch push and PR
against `codex/release-radar-mvp`. Each merge needs owner approval. No installation,
owner/application-state mutation, cloud provisioning, active configuration change or
production implementation. List retained temporary files; do not delete unrelated
files. Report exact commit, checks, limitations and stopped processes to the
orchestrator before archival.

## Findings

### Conclusion

**Pursue a small, repository-local pilot only after separate owner authorization.**
Codex supports both command rules and lifecycle hooks, but neither is a complete
security boundary or a substitute for task authorization, direct verification,
or independent review. The pilot should contain two narrow controls and one
reminder; it should not create a task database, parse transcripts, or perform
GitHub mutations.

### Verified support

| Claim | Evidence | Consequence |
| --- | --- | --- |
| Command rules are experimental, prefix-based outside-sandbox controls with `allow`, `prompt`, and `forbidden` decisions. | [Official Rules documentation](https://learn.chatgpt.com/docs/agent-configuration/rules) | Suitable for a small deny-list, not for proving that tests, commits, reviews, or PRs happened. |
| The installed `codex-cli 0.153.4` lists `hooks` as stable and exposes `codex execpolicy check`. | Local `codex features list`, `codex execpolicy check --help` | A dry rule test is available before any configuration is trusted. |
| Hooks can be project-local (`<repo>/.codex/hooks.json`) but need project trust and separate hook-definition trust. | [Official Hooks documentation](https://learn.chatgpt.com/docs/hooks) | Do not silently enable a repository hook; the owner must review/trust it in the target client. |
| `PreToolUse` can deny supported local tool calls; `PostToolUse` observes results but cannot undo side effects; hosted tools are outside that hook path. | [Tool coverage and hook semantics](https://learn.chatgpt.com/docs/hooks) | Treat hooks as defense-in-depth and record only supported, local tool results. |
| `Stop` can request one continuation, while `stop_hook_active` identifies a turn already continued by `Stop`. | [Stop event contract](https://learn.chatgpt.com/docs/hooks) | A reminder must allow STOP, approval waits, questions, and blockers, and must cap itself at one continuation. |

Isolated proof: a temporary `.rules` file containing `prefix_rule(["git",
"push"], "forbidden")` produced `decision: "forbidden"` for `git push origin
codex/example`; `git pull origin codex/example` produced no match. This proves
the installed checker evaluates a narrow prefix rule. It does **not** prove
runtime loading, project trust, hook trust, or hook execution.

### Smallest proposed pilot

1. A project-local rule file denies only unambiguously unauthorized publication
   prefixes—initially `git push`, `gh pr create`, and `gh pr merge`—with a
   justification directing the agent to seek owner authorization. It has
   `match`/`not_match` examples and is checked with `codex execpolicy check`.
   It does not allow commands, change sandbox/approval settings, or attempt to
   classify shell wrappers beyond Codex's documented parser.
2. A trusted, synchronous `PostToolUse` hook watches `Bash` only and emits
   concise, non-secret context for the explicitly selected test, local commit,
   and authorized-PR commands. It records a result only after the command
   returns, including a non-zero exit. It neither runs a command nor treats
   tool success as product success.
3. A trusted `Stop` hook reads only explicit, task-scoped completion fields
   supplied by the future pilot configuration. It may request **one** bounded
   continuation when a selected check or documented endpoint is absent. It
   must return normally for owner STOP, interruption, approval-required state,
   questions, explicit blockers, review-only tasks, or an already-active Stop
   continuation. Persistent absence is reported, not looped.

The future configuration task should use `.codex/hooks.json` plus a small
repo-owned executable (not a global hook), because official documentation says
that project hooks load only in trusted projects and are independently
reviewed. No hook should inspect `transcript_path`: the official contract says
that transcript format is not stable for hooks.

### Explicit gaps and no-go boundaries

- Rules cannot require a test, documentation disposition, local commit, or PR;
  they only decide matching command permission outside the sandbox.
- Hook coverage excludes hosted tools and may exclude specialized paths, so the
  pilot must not claim universal enforcement or prevent owner-authorized work
  through another supported path.
- `PostToolUse` cannot reverse a push, commit, or other completed action;
  publication authority remains with the owner and normal approval system.
- Hooks may run concurrently, and asynchronous hooks cannot control the action
  that triggered them. The proposed policy/reminder hooks are synchronous and
  intentionally independent, not a pipeline.
- There is no verified mechanism here to disable subagent creation only for an
  orchestrator while retaining delivery-task capabilities. That remains an
  unresolved runtime-capability question and is excluded from this pilot.

### Compatibility, privacy, and recovery

Rules are documented as experimental, so the configuration must pin the
verified Codex version in the future pilot evidence and re-run its isolated
checker after upgrades. Hook output must contain no credentials, owner data, or
transcript content; oversized hook output can be written to local temporary
storage by Codex. Failure to load, trust, or execute a hook must leave the
normal approval and task workflow available and report the condition—never
block recovery or manufacture completion.

### Future authorized test plan

In a dedicated configuration worktree, test (1) exact rule matches and nearby
non-matches, (2) denied publish versus an owner-authorized escape documented in
the task endpoint, (3) successful and failing selected test commands,
(4) no continuation on STOP/approval/blocker/review states, (5) exactly one
continuation for a genuinely missing selected field, and (6) restart/trust
behavior in the installed client. Obtain one independent review covering the
command-policy and recovery/continuation risks. Do not install or enable
anything as part of this discovery.

### Disposition

This is a proposed, non-gating I9 result. It does not change accepted Mac or
repository authority, retained history, product scope, RDS appearance, C4, or
any existing governing configuration.

Temporary files retained: `/tmp/release-radar-rules-hooks.87hPRM/pilot.rules`
(isolated rule-check input). It is not a deliverable and has not been deleted.
