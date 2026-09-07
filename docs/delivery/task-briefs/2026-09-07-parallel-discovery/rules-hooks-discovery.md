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

**No-go for a runtime I9 pilot on the currently demonstrated capability.**
Codex supports command rules and lifecycle hooks, but the proposed uses cannot
preserve task-scoped authorization, distinguish legitimate completion exits, or
demonstrate data minimization. They remain unsuitable as a substitute for task
authorization, direct verification, or independent review. No configuration,
hook executable, or rule should be adopted from this discovery.

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

### Why the initially plausible pilot is rejected

1. A `forbidden` rule for `git push`, `gh pr create`, or `gh pr merge` is
   context-blind: Rules compare argv prefixes and the strictest matching rule
   wins, whereas this programme authorizes those endpoints per task and owner
   decision. `forbidden` blocks without a prompt. An unspecified escape would
   either bypass the same control surface or fail the normal authorized
   endpoint. Do not hard-forbid these commands.
2. `Stop` supplies common fields plus `turn_id`, `stop_hook_active`, and
   `last_assistant_message`; it has no matcher and no structured task type,
   endpoint, approval-wait, question, or blocker state. Transcript parsing is
   explicitly excluded and not stable. `stop_hook_active` can cap a
   continuation but cannot identify a legitimate exit. Do not adopt a Stop
   reminder without a separately specified, stable, fail-open state source and
   ownership contract.
3. A `PostToolUse` matcher for `Bash` receives every covered command's full
   input and response, including unrelated failing output. Merely emitting
   selected non-secret context does not minimize what a repository executable
   receives. Do not adopt it without proof of input minimization, no
   persistence/network behavior, and executable-change trust semantics.

Project-local hooks still require project and definition trust, but that does
not establish whether changing a referenced executable retriggers trust. No
hook should inspect `transcript_path`: the official contract says that
transcript format is not stable for hooks.

### Explicit gaps and no-go boundaries

- Rules cannot require a test, documentation disposition, local commit, or PR;
  they only decide matching command permission outside the sandbox and cannot
  observe task-specific authorization.
- Hook coverage excludes hosted tools and may exclude specialized paths, so the
  pilot must not claim universal enforcement or prevent owner-authorized work
  through another supported path.
- `PostToolUse` cannot reverse a push, commit, or other completed action;
  publication authority remains with the owner and normal approval system.
- Hooks may run concurrently, and asynchronous hooks cannot control the action
  that triggered them. A hook is not a pipeline or an authorization engine.
- There is no verified mechanism here to disable subagent creation only for an
  orchestrator while retaining delivery-task capabilities. That remains an
  unresolved runtime-capability question and is excluded from this pilot.

### Compatibility, privacy, and recovery

Rules are documented as experimental, so any later exploration must pin the
verified Codex version and re-run its isolated checker after upgrades. Hooks
receive input as well as produce output; both could contain credentials or owner
data, and oversized output can be written to local temporary storage by Codex.
A later proof must establish minimization before a repo-owned executable sees
any data, no persistence/network behavior, and whether modifying that executable
requires a fresh trust decision. Failure to load, trust, or execute a hook must
leave the normal approval and task workflow available and report the
condition—never block recovery or manufacture completion.

### Future authorized test plan

Before any new configuration proposal, an independently reviewed feasibility
task must establish (1) a supported approval-aware control that allows the
normal task-authorized publish endpoint while denying the same endpoint without
authorization, (2) a stable, owned, fail-open task-state interface that
distinguishes every required Stop exit without transcripts, and (3) a
data-minimized hook input boundary, no persistence/network behavior, and fresh
trust behavior after executable changes. It must test those exact properties in
the installed client, not merely `execpolicy`. Absent those proofs, retain this
no-go and do not install or enable anything.

### Disposition

This is a proposed, non-gating I9 result. It does not change accepted Mac or
repository authority, retained history, product scope, RDS appearance, C4, or
any existing governing configuration.

Temporary files retained: `/tmp/release-radar-rules-hooks.87hPRM/pilot.rules`
(isolated rule-check input). It is not a deliverable and has not been deleted.
