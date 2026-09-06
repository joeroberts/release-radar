# ADR-007: Proportional Delivery Validation

- Status: Accepted; owner-approved
- Date: 2026-09-01
- Operating-model amendment: 2026-09-06, requested by the owner; committed
  baseline review and approval state is recorded in `docs/delivery/progress.md`.

## Context

The mandatory all-role delivery model caused recursive validation, oversized
briefs, duplicated evidence, and operational-context inflation. The process
could become larger than the product change without adding corresponding
confidence.

## Decision

The repository-root `AGENTS.md` is the operative risk-triggered delivery policy.
Work uses three stages:

1. **Start:** authorization, scope, dependencies, and material risks are clear.
2. **Implement:** behavior changes use test-first development and focused
   repository-native checks.
3. **Complete:** the changed behavior is directly verified and receives the
   independent review required by its risks.

Every material implementation retains an independent reviewer other than its
implementer. Ordinary documentation needs one independent review and applicable
documentation validation; ordinary code behavior needs focused tests and one
independent code or QA review. Architecture, Security/Privacy, UX, and TPM
reviews are added only for the triggers defined in `AGENTS.md`. Delivery
Management records current state and evidence rather than supplying another
technical approval. Reviewers explicitly requested by the owner remain
required for that task.

Direct product evidence takes precedence over process evidence. Successful
direct tests and independent reviews are terminal unless they identify a
defect; reviews are not recursively reviewed. Mutable plans, briefs, indexes,
and progress records are not checksum-controlled. Immutable evidence may be.

Older mandatory review ceremony is superseded for unopened work. Older product,
persistence, security, test, dependency, and acceptance requirements remain
valid. Completed work is not retroactively invalidated, and historical plans,
briefs, and evidence remain unchanged.

This decision governs M2–M8 of the Managed Repository Documentation Contract
and all other unopened repository work.

## Task-based delivery and whole-product architecture

The owner selected a coordinating task that creates and monitors separate delivery
tasks, with optional bounded subagents inside delivery tasks. The orchestrator
does not use subagents or implement product slices. Delivery writers use separate
worktrees and explicit ownership. Independent review uses a fresh task for the
specified candidate, with the original requirement, applicable architecture and
future dependencies, rather than the implementer's conversation history.

A separate chief-architect task maintains the whole-product view across slices.
It tracks decisions, direction, dependencies and tradeoffs in existing ADRs,
designs and the [full-product plan](../delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
The feature architect handles the current slice within those constraints. Consult
the chief architect when shared identities, persistence, public contracts,
authority, recovery or future consumers are affected. Routine conformance does
not need another approval. Chief architecture cannot approve new owner scope or
independently review its own material design.

The orchestrator and chief architect have continuing responsibilities, with
replaceable conversations. Delivery and review tasks cover one brief/slice and its
corrections. Integration covers one bounded set; a phase is suitable only when it
is itself bounded. Delivery management normally belongs to the orchestrator, and
feature architecture/QA normally belong within the relevant task. These are
capabilities selected for the work, not a mandatory roster of separate tasks.

Before dispatch, record the relevant product consumers and compatibility,
migration and recovery implications in the existing brief. Link to authoritative
material and distinguish accepted contracts from directional proposals. Preserve
future compatibility without implementing speculative features. Do not make
every repair wait for the detailed design of every future feature.

Workers start from a named committed baseline that contains the operating policy
and product plan. Assign one integration writer and one progress-ledger writer.
Worktrees do not isolate SQLite, installed apps, credentials, ports or shared Git
metadata; shared mutations remain serialized and separately authorized. Finish and
preserve the result before ending a task; archived status is not proof that a run
or external process stopped. The orchestrator must promptly archive bounded delivery,
integration and review tasks after their outcome and required corrections are
complete, durable results are saved and processes have stopped. Parent-level owner
approval does not keep a completed child open. Record the outcome and archive status
in the existing progress ledger. Only required corrections to that same outcome may
reuse or restore a task; a new candidate outside that correction scope or a
separate handoff review uses a fresh task. This owner clarification was requested on 2026-09-06. No new task database,
architecture registry or parallel ledger is introduced.

## Assignment and completion policy

Root AGENTS.md owns the model/effort table so it does not drift across duplicate
matrices. The owner selected differentiated Luna, Terra, Sol and Astra assignments,
with effort chosen independently and explicit dispatch settings. **Ultra is
prohibited for every task, subagent, default and escalation path.** Orchestration
starts at Astra Medium, chief architecture at Astra High, ordinary implementation
at Terra Medium, complex design/recovery at Sol High, and bounded mechanical work
at Luna Low/Medium. Review and QA strength follows the actual risk.

The orchestrator selects the starting profile and an authorized escalation ceiling.
It identifies the unresolved problem before escalating, checks context and tooling,
and escalates only the difficult portion where practical. Extra High/Max are
exceptions requiring a specific authorized reason; Ultra is never an exception.
Model choice does not alter scope, independence or acceptance criteria. Learn from
actual completion, rework and resource use using existing task results.

Choose minimum risk coverage before dispatch. A qualified reviewer can cover
multiple concerns; ordinary code needs one code or QA review, not both by default.
Classify findings as Required, Optional or Out of scope. Only Required findings
block. Correct those and repeat only affected checks and relevant review of the
correction. Successful validation is terminal. Do not review reviewers, reopen
closed checks for optional suggestions or add another role for the same property.
A new requirement, material change or named unresolved risk is needed to reopen
validation. Repeated failure calls for diagnosis and simplification, not escalation
of process.

Each assignment states the delivery endpoint, applicable tests and documentation
disposition. Delivery owns the scoped local commit when authorized and follows
through to an authorized PR/push or reports the specific blocker. Neither task
completion nor a Git commit implies owner acceptance, application state changes,
installation or publication. This operating baseline itself stops at a reviewed
local commit for owner approval; its product pilot is a later authorized task.

## Runtime enforcement and adoption

This amendment documents the operating model; it does not claim installed technical
enforcement. The local task interface supports explicit model/effort assignments,
but changing repository prose does not remove tools. Current official documentation
describes [subagent settings](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[command rules](https://learn.chatgpt.com/docs/agent-configuration/rules) and
[lifecycle hooks](https://learn.chatgpt.com/docs/hooks). Verify applicable support
in the installed client before relying on role-specific restrictions. In
particular, subagent-tool disabling must apply to the orchestrator without silently
disabling delivery-task capabilities. Do not install a global workaround.

I9 retains the separate, bounded configuration work: supported restrictions and
completion reminders with legitimate STOP/approval/blocker exits, accurate direct
results, no automatic publication and no recursive validation machinery. The
first product pilot can test task separation, model assignment and bounded delivery
without claiming those hooks are installed or making them a prerequisite.

The local committed baseline includes the full-product plan. The owner reviews and
approves that baseline before receiving the new-task prompt for the selected C8
pilot. The plan's proposed product contracts remain proposed unless specifically
approved. Existing canonical documentation-validation and application-binding
failures remain separately reported recovery states; local baseline preparation
does not repair or accept the application's documentation catalog.

## Rationale

Risk-triggered validation preserves independent implementation review and the
project's authorization, data, security, and verification boundaries while
keeping evidence proportional to the change. It directs effort toward
observable behavior and concrete risks instead of proof that another process
step occurred.

## Supersession

This ADR supersedes pre-M1A requirements that mandate full-role review matrices,
mutable-document checksums, exact-brief hashes, commit-parent formulas, repeated
remote-equality gates, or validation of another validation for unopened work.
It does not supersede their product or safety requirements and does not alter
completed records.
