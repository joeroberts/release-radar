---
name: shared-execution
description: Use when performing authorized implementation or substantive review work in a repository that has adopted shared-execution standard v1.
metadata:
  shared-execution-standard: 1
---

# Shared Execution

Apply shared-execution standard v1 within the exact authority of the current
repository and task. This skill supplies bounded context and honest reporting; it
does not authorize work or replace local product, architecture, safety, recovery,
or delivery decisions.

## Required task context

Carry these eight fields in plain text. Link task-relevant controllers instead of
copying them, and add conditional identity or recovery fields only when they apply.

| Field | Required content |
| --- | --- |
| Standard | `shared-execution/1` and the observed plugin/skill compatibility state |
| Root | One exact absolute task root, or `unknown` before repository action |
| Outcome | One complete owner-requested outcome in one or two sentences |
| Scope | Owned paths/systems, exclusions, and non-gating dependencies |
| Authority | Task-relevant controlling artifact IDs/paths and source basis |
| Endpoint | The actually authorized endpoint; all others remain excluded |
| Direct checks | Repository-owned commands/properties and what each establishes |
| Review | Required independent review, candidate identity, and named risks |

## Standard clauses

- **SEI-1 — Local authority wins.** Read local indexes and only task-relevant
  controllers. Explicit owner authorization, local contracts, and the local ledger
  remain authoritative; this standard cannot expand scope, sequence, or acceptance.
- **SEI-2 — Minimum context only.** Carry the required fields and applicable
  conditionals. Do not copy closed history, transcripts, exhaustive inventories, or
  evidence whose only purpose is proving that process occurred.
- **SEI-3 — Exact root and source basis.** Never substitute a parent, child, prefix,
  or similarly named folder. Report Git `HEAD` and scoped state when available:
  clean is `exactRevision`, dirty is `workingTree`, and unresolved is `unknown`.
- **SEI-4 — Existing checks first.** Use repository-owned checks and the bounded
  task brief. For managed documentation use the installed checker at the exact
  authorized root. Do not invent a general recipe executor or unrelated suite.
- **SEI-5 — Honest direct results.** Report the runner, scope, source, applicability,
  direct result, and limitation actually observed. Missing evidence is never a pass.
- **SEI-6 — Typed mutation boundary.** Release Radar mutations retain the exact
  root, current registration and generation, canonical body, and stable request ID.
  Reconcile uncertainty through supported readback or exact replay.
- **SEI-7 — Proportional independent review.** Material implementation has one
  suitable reviewer other than its implementer. Add specialists only for a named
  risk; classify findings Required, Optional, or Out of scope. Only Required blocks.
- **SEI-8 — Owner acceptance and external effects remain explicit.** Checks,
  reviews, commits, digests, receipts, and task completion imply none of acceptance,
  push, merge, installation, trust, permission, publication, or owner-state change.
- **SEI-9 — Fail honest and recover forward.** Keep stale, missing, inaccessible,
  incompatible, interrupted, and uncertain states visible. Preserve content,
  receipts, IDs, and history; never weaken trust or silently retry uncertain writes.
- **SEI-10 — Completion stops the process.** Stop when the authorized outcome,
  direct checks, required review, and authorized endpoint are complete. Optional
  suggestions do not create more scope or validation layers.

## Direct result row

Report each check with `Check`, `Runner`, `Scope`, `Source`, `Applicability`,
`Status`, `Direct result`, and `Limitation`. Status is exactly one of `passed`,
`failed`, `skipped`, `unavailable`, `unknown`, or `notRun`. Applicability is exactly
one of `exactRevision`, `workingTree`, or `unknown`. A catalog digest is neither
content approval nor a code revision or review attestation.

## Consumer adoption block

Use this block only in an exact owner-authorized adoption preview. Preserve every
local outcome and stricter rule, and keep independent local fallbacks for material
review, owner acceptance/external effects, and safety/recovery.

```markdown
<!-- release-radar-shared-execution:v1:start -->
## Shared execution integration

For authorized implementation or substantive review work, invoke the installed
`$release-radar:shared-execution` skill and apply shared-execution standard v1.
This repository's explicit owner authorization, controlling product and architecture
documents, and delivery ledger remain authoritative. The shared standard supplies
bounded context, repository-native check reporting, and compatibility diagnostics
only; it cannot grant authority, accept work, identify an independent reviewer,
change delivery state, or trigger installation, trust, permissions, publication,
or any other action. If the skill is missing, modified, incompatible, or unavailable,
report that state and use only this repository's own governing instructions. The
repository must independently retain its requirements for material independent
review, explicit owner acceptance and external effects, and material safety and
recovery. If those local fallbacks do not cover every removed required clause, stop
the affected material work; unrelated read-only and product work may continue under
the local instructions.
<!-- release-radar-shared-execution:end -->
```
