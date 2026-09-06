# C8 pilot kickoff prompt

The owner approved operating baseline `44dc75b1cf63837e22e5cf18773178576d55c618`
on 2026-09-06. This is the requested handoff for a new task, not an instruction to
start the pilot in the baseline-preparation task. Select **GPT-6 Astra / Medium**
for the new orchestrator. Copy the prompt below; use the handoff commit supplied
with it as the starting revision. This file supports the handoff and is not the
controlling implementation brief.

```text
Act as the Release Radar C8 pilot orchestrator using the approved task-based
operating model. Never use Ultra in any task, subagent, default or escalation.

Repository: /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar
Approved operating baseline: 44dc75b1cf63837e22e5cf18773178576d55c618.
Start from the handoff commit containing this prompt, on the local branch
codex/full-product-architecture-plan. Preserve the older canonical checkout and
its unrelated changes. All implementation workers must use isolated worktrees
with the assigned baseline, operating documents and product plan available.

Read AGENTS.md, docs/README.md, the relevant docs/catalog.json entries, ADR-007,
docs/delivery/progress.md and the full-product architecture plan. The operating
baseline is approved; the plan's other proposed product contracts retain their
stated approval boundaries. Preserve the complete intended product and identify
C8's future consumers before selecting the compatibility approach.

I authorize this new task to run the bounded C8 source-repair pilot: prepare the
required brief, create and monitor the separate tasks below, implement the narrow
validator repair with its contract/reference updates, run direct checks, obtain
independent review and produce scoped local commits. The orchestrator coordinates
and owns progress; it must not implement product code or spawn/reuse subagents.

Create separate Codex tasks with explicit actual model/effort settings:
- Chief architect: gpt-6-astra / high. Resolve C8's versioned compatibility approach
  against the full-product constraints. Keep the assignment bounded; record the
  conclusion in the existing appropriate design/ADR or C8 brief, without inventing
  scope. This task's responsibility is whole-product alignment, not extra approval.
- Delivery owner: gpt-5.6-terra / medium. Own the C8 code, affected documentation,
  focused tests, corrections and local integration/commits. It may use bounded
  subagents only when justified and with explicit model/effort and ownership.
- Independent reviewer: gpt-5.6-sol / high. Use a fresh task for the candidate,
  original requirements and relevant future dependencies, without forking the
  implementer's conversation. Cover reader correctness, the contract and filesystem
  safety in this one review. Do not create a reviewer for the reviewer.

Sequence these tasks according to dependencies. Persist a concise C8 brief under
tracked docs/delivery/task-briefs before releasing the delivery writer. Name scope,
future dependencies, ownership, tests, risks, review coverage and delivery endpoint.
Coordinate catalog/index writes and maintain one progress writer. Set actual model
settings when dispatching, with Astra High as the default escalation ceiling;
Extra High/Max require specific owner authorization. Ultra is never eligible.

Implement only C8's exact .DS_Store exclusion for ordinary regular files during
managed-document discovery, after checking file type without following symlinks.
Same-named directories/symlinks, other prohibited paths, unregistered documents and
attempts to catalog excluded metadata must still reject. Metadata-only changes
must not change document inventory or catalog digest. Preserve root containment,
artifact identity, evidence restrictions and existing real-document validation.
Update the documented versioned rule and shipped reference together with the code.
Do not substitute .gitignore changes, metadata deletion or a blanket hidden-file
exclusion. Broader freshness, lifecycle, recovery and hooks work stays outside C8.

Use existing repository-native tests and tools. Add focused regressions for root
and nested metadata and the rejection cases; verify app-reader/bundled-checker
agreement. Run broader checks only for a named affected risk. Classify review
findings as Required, Optional or Out of scope. Correct required defects and repeat
only affected checks; optional suggestions do not reopen completion.

Carry the source candidate through verified local commits and report the result.
Do not push, publish a PR, merge, change installed apps, mutate owner/application
state, bind or accept a catalog, reconstruct audits, delete metadata, or install
rules/hooks under this prompt. If installed acceptance requires changing the app,
prepare the concrete installation candidate and request authorization for that
exact step. Source verification alone does not complete C8's installed acceptance;
retain any remaining acceptance step explicitly rather than silently dropping it.

Monitor dispatched tasks through completion. A pending creation ID or missing
list entry is not proof of setup failure: resolve the actual task ID through
supported status and narrow local diagnostics before asking the owner to inspect
it. Avoid duplicate workers or repeated unchanged polling. Archive bounded delivery
and review tasks after their work has stopped and useful results are preserved.
Do not reuse a completed reviewer for a new candidate or unrelated handoff.

Conclude with commits, changed behavior/docs, direct checks, review result, remaining
installed-acceptance or authorization needs, and a short assessment of the pilot's
follow-through, context gaps and model usage where available. Keep this in existing
delivery records. Do not build a new ledger, scorecard, validator framework or
review machinery. Do not start the next product slice automatically.
```
