# Release Radar Agent Instructions

## Scope and Controlling Artifacts

These instructions apply to the entire repository.

Treat the user's explicit request and the approved project artifacts as the
controlling sources for Release Radar. Current artifacts include:

- `docs/delivery/plans/2026-08-29-delivery-goals-roadmap-readiness.md`
  for the delivered RR-R10 scope and retained task boundaries
- `docs/delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md`
  for whole-product dependencies and assessed future direction; preserve its
  distinction between approved inclusion, proposed contracts and implementation
- `docs/architecture/ADR-007-proportional-delivery-validation.md` for the
  operating model and bounded validation policy
- `docs/design/agent-driven-delivery-dashboard-design.md` and
  `docs/design/mockups/` for product and visual design
- `docs/architecture/ADR-001-release-radar-boundaries.md` for architecture,
  data, integration, sandbox, and signing boundaries
- `docs/brand/README.md` for the approved product identity
- `docs/delivery/progress.md` for delivery status, decisions, verification,
  risks, and the next eligible task

Do not silently override approved artifacts with assumptions, generated plans,
repository indexes, or implementation convenience. Treat `.codegraph` output
as a navigation aid and verify consequential findings against the current
source, tests, configuration, application bundle, or running app as
appropriate.

## Design References

Design screenshots are stored under `docs/design/mockups/`. Each filename
identifies the section or feature it represents.

- Inspect the relevant screenshot before planning, implementing, or reviewing
  a UI feature.
- Use the screenshots as the visual reference for layout, responsive behavior,
  design language, colors, patterns, branding, iconography, spacing, and
  interaction design.
- Compare the running application with the screenshots. Source inspection alone
  is not evidence of visual correctness.
- Record necessary deviations and their rationale in the applicable design
  document or architecture decision record.

## Durable Artifact Placement

Paths under `~/.codex`, `/tmp`, and thread-scoped visualization directories are
temporary scratch space only. They are never the source of truth for Release
Radar deliverables.

- Persist durable Release Radar design documents under `docs/design/`.
- Persist approved Release Radar mockups under `docs/design/mockups/`.
- Persist every approved or controlling implementation task brief under
  `docs/delivery/task-briefs/` before implementation begins. A tracked artifact
  must never cite `/tmp`, `.superpowers/sdd/`, another Git-ignored path, build
  output, or agent-session storage as its controlling brief.
- When an approved brief originates in temporary or ignored storage, move the
  exact reviewed artifact to the tracked task-brief path, verify the copy, and
  update every controlling reference before releasing a writer.
- Preserve human-authored historical drafts, role reports, review packages, and
  superseded briefs under `docs/delivery/archive/` when the owner requests
  archaeological retention. Archive content must be labelled historical and
  non-authoritative; it does not compete with `docs/delivery/progress.md` for
  current status or sequencing.
- Never present a scratch path as the final deliverable.
- Before requesting approval or declaring completion, classify every created
  file as durable or temporary.
- Completion is blocked while any durable artifact exists only outside the
  repository.
- Verify repository copies before reporting persistence.
- Final responses must link to repository paths, not scratch copies.
- List any remaining temporary files and request authorization before deleting
  them.

## Risk-Triggered Delivery Model

Delivery roles are capabilities selected according to actual task risk; they
are not mandatory participants in every task. Every material implementation
must receive independent review by someone other than its implementer.

- Ordinary documentation requires one independent reviewer and applicable
  documentation validation.
- Ordinary code behavior requires focused tests and one independent code or QA
  review.
- Architecture review is required only for public contracts, persistence
  schemas, accepted architecture decisions, or cross-component boundaries.
- Security/Privacy review is required only for authorization, owner data,
  credentials, external content, evidence relocation, root or symlink
  containment, destructive operations, or external mutations.
- UX review is required only for user-facing workflows, guidance, errors,
  accessibility, or presentation.
- TPM review is required for initial sequencing and dependencies or a material
  scope or sequencing change.
- Delivery Management records current state and evidence; it is not an
  additional technical approval.
- Reviewers explicitly requested by the owner remain required for the task in
  which they were requested.

An agent may not review, approve, or independently verify its own
implementation.

Before dispatch, the orchestrator identifies the minimum review coverage justified
by the actual change. One qualified independent reviewer may cover several risks;
roles do not each require a separate task. Classify findings as Required, Optional,
or Out of scope. Only Required findings block. New review coverage requires a named
unresolved risk or an explicit owner requirement; reviewers cannot add approval
layers or authorize scope expansion.

## Execution Authorization Boundaries

- “Consider,” “discuss,” “evaluate,” or “recommend” authorizes no tool use or
  changes unless the owner explicitly requests inspection.
- Eligibility does not constitute authorization.
- `STOP` immediately prohibits further tools, writes, tests, subagents, Git
  operations, Release Radar mutations, and external actions.
- Only an explicit owner resume naming the task and authorized action clears a
  stop. “Approved” alone does not resume stopped work.
- Owner data, application state, and external mutations require explicit owner
  authorization. Authorization for local repository work does not authorize
  them.
- Destructive actions require explicit authorization, exact target resolution,
  and the least destructive practical method.
- Release Radar remains the exclusive writer of its SQLite store. Agents and
  repository tools must not edit SQLite directly; authorized state changes use
  supported, typed, audited application operations.
- After implementation begins, returning to planning requires explicit owner
  authorization.

## Execution Gates

1. **Start:** Authorization, scope, dependencies, and material risks are clear.
2. **Implement:** Use test-first development for behavior changes and run
   focused repository-native checks.
3. **Complete:** Directly verify the changed behavior and obtain the independent
   review required by the risk rules.

- A successful direct test or independent review is terminal unless it
  identifies a defect.
- Do not review a review.
- Do not checksum review reports or mutable plans and briefs.
- Do not create evidence solely to prove that another validation occurred.
- Do not repeat worktree, branch, commit-parent, or remote-equality checks
  around every intermediate action.
- Stop repeated attempts only when substantially identical attempts produce no
  new evidence, continuing would expand scope, or continuing risks damage.
- An in-scope correction may proceed under existing authorization unless it
  expands scope, introduces a new side effect, or touches owner or external
  state.

Review matrices, mutable-document checksums, exact-brief hashes, commit-parent formulas, repeated remote-equality gates, and validation-of-validation requirements recorded in plans or briefs before the M1A proportional-delivery decision do not control unopened work. Their product requirements, architecture and security boundaries, dependencies, tests, and acceptance criteria remain controlling. Any exception to this proportional model requires explicit owner approval identifying the concrete risk it addresses.

## Task Briefs

Task briefs are required only for multi-step, cross-subsystem, destructive,
migration, security-sensitive, or otherwise high-risk work. A brief contains
only:

- Objective and outcome
- Scope and exclusions
- Dependencies
- Material risks
- Test strategy
- Acceptance criteria
- Risk-triggered reviews
- Assignment: owner, baseline branch/revision, file/shared-state ownership,
  model and effort with rationale and escalation ceiling
- Relevant accepted architecture and future consumers, with links; identify
  migration, compatibility and recovery implications or state why none apply
- Delivery endpoint: documentation disposition, checks and local commit expected;
  separately state authorization for push, PR, merge, installation and app state

Briefs must not reproduce entire designs or ADRs, reviewer transcripts, exact
commit-parent choreography, long inventories of unchanged files,
mutable-document checksums, or validation evidence whose only purpose is
proving another validation.

## Progress Ledger

Use `docs/delivery/progress.md` as the durable delivery source of truth. Do not
create a competing ledger.

Record only:

- Current outcome and active task
- Current authorization state
- Controlling plan or brief
- Current blockers and risks
- Concise verification result or link
- Next eligible work

Do not add complete review transcripts, exhaustive command output, candidate
hashes, repeated Git-state evidence, or detailed closed-task chronology. Code
or compilation alone does not make a task complete.

## Task Ownership and Lifecycle

The orchestrator coordinates separate Codex tasks and monitors their outcomes.
It must not spawn or reuse subagents. Under the owner's task-creation authorization,
use fresh tasks for separate outcomes and fresh worktrees for delivery writers.
Task creation is asynchronous: resolve setup, then monitor completion, blockers and
required owner decisions. A successful dispatch is not a completed assignment.

- **Orchestrator:** programme-level scope, dependencies, assignments, integration
  ownership and follow-through. It owns the progress ledger by default. It does
  not perform product implementation; route that work to bounded delivery tasks.
- **Chief architect:** a separate peer task responsible for whole-application
  direction, accepted/proposed decisions, future dependencies and tradeoffs. Consult
  it for shared identities, persistence, public contracts, authority, recovery or
  cross-feature boundaries. It cannot invent scope or override owner decisions.
- **Delivery owner:** one complete brief/slice, including affected documentation,
  direct verification, corrections and the authorized commit/PR endpoint. Use a
  phase only when it is itself a bounded, coherent outcome. Feature architecture
  and QA expertise may sit within this task; substantial prerequisite design can
  have its own bounded task.
- **Independent reviewer:** one specified candidate and its required corrections
  in a fresh task. Provide the original outcome, relevant product constraints,
  candidate and direct evidence; do not fork the implementer's conversation. An
  author cannot independently review their own implementation or material design.
- **Integration owner:** one bounded set of related changes. Usually the delivery
  owner; create a separate task only for substantial coordination or conflicts.
  Assign one writer for each integration checkout and shared resource.
- **Delivery management:** records state and ensures the agreed endpoint is reached;
  normally the orchestrator's responsibility, not an extra technical approval.

Orchestrator and chief-architect responsibilities persist across slices, but their
conversations may be replaced from the existing plan, ADRs and progress ledger.
Delivery, integration and review tasks end with their assigned outcome; reuse them
only for corrections to that same outcome. Do not recycle a task for an unrelated
role. Archive only after work/processes are known to have stopped; archiving alone
does not prove cancellation. Preserve useful results in the repository first.

Delivery tasks may use subagents only for concrete bounded work with relevant
requirements, explicit model/effort and separate ownership. Never use an implementer
as their own independent reviewer. Do not create a chain of reviewers. If the
interface cannot retire a subagent, stop using it when its assignment ends; use a
fresh delivery task when fresh context/capacity is needed.

Worktrees isolate checked-out files, not application SQLite, Keychain, installed
apps, ports or all Git metadata. Serialize authorized shared-state mutations. Each
worker starts from the assigned committed baseline containing the operating docs
and product plan, not an implicit default branch or dirty canonical checkout.
The orchestrator releases dependent work only after the needed contract/change is
available in that worker's baseline. Parallel writers need disjoint ownership.
Workers report commits, changed behavior/docs, direct checks and unresolved risks;
only the designated ledger writer integrates status.

## Model and Effort Assignments

**Ultra is prohibited everywhere: tasks, subagents, defaults and escalation paths.**
No fallback, profile or automatic delegation mode may select Ultra.

Choose model capacity and reasoning effort separately, based on ambiguity, affected
boundaries, consequences and available verification. These starting profiles are
owner-selected operating defaults, not guarantees of model quality:

| Work | Starting model / effort | Escalation when justified |
| --- | --- | --- |
| Orchestrator | `gpt-6-astra` / `medium` | `high` for conflicting dependencies or difficult scope/integration decisions |
| Chief architecture | `gpt-6-astra` / `high` | `xhigh` only for a named difficult cross-product conflict within an authorized ceiling |
| Feature architecture | `gpt-5.6-sol` / `high` | Astra `high` for shared contracts or application-wide assumptions |
| Ordinary implementation | `gpt-5.6-terra` / `medium` | Sol `high` for substantial ambiguity, debugging or cross-component behavior |
| Complex recovery/migration | `gpt-5.6-sol` / `high` | Astra `high` for difficult authority, compatibility or data preservation |
| Bounded edits, fact extraction, recording verified results | `gpt-5.6-luna` / `low` or `medium` | Terra `medium` when interpretation is necessary |
| QA | `gpt-5.6-terra` / `medium` for defined scenarios | Sol `high` for exploratory/recovery journeys and difficult diagnosis |
| Independent review | `gpt-5.6-terra` / `high` for ordinary changes | Sol `high` for complex work; Astra `high` for consequential architecture/data risks |
| Integration | `gpt-5.6-terra` / `medium` for straightforward changes | Sol `high` for behavioral conflicts; Astra `high` for architecture decisions |

Set the actual model and effort at task/subagent dispatch; a brief alone does not
configure execution. Confirm returned settings where the interface exposes them;
otherwise report the verification limitation. Do not silently substitute an
unavailable model or inherit an unspecified effort. A stronger reviewer is not a
substitute for independent context, and more effort does not make models equivalent.

The orchestrator selects profiles within the owner's agreed policy and assignment
ceiling. The default ceiling is Astra `high`; `xhigh` or `max` needs a specific
reason and owner authorization unless already included in that assignment. Ultra
is never eligible. Check missing context, tooling and scope before escalating.
Escalate a named unresolved problem, not every failed test; prefer a bounded stronger
analysis to repeated retries or upgrading all work. Corrections retain the original
scope and do not restart planning or add reviewers. Evaluate assignments using
completion, rework, missed requirements, elapsed time and usage when available;
record only useful conclusions in existing delivery records.

## Follow-through and Enforcement Boundaries

Completion includes the agreed working outcome, relevant documentation, direct
checks, required independent review and authorized delivery endpoint. When local
commits are authorized, make the scoped commit after verification; when a PR/push
is authorized, follow through to that endpoint or report its specific blocker.
Do not silently stop at uncommitted code, and do not infer external authorization.
Ordinary corrections repeat only affected checks and applicable review. Optional
suggestions never reopen completion or trigger another review cycle.

This baseline defines operating instructions. It does not install Codex rules,
hooks, model profiles or technical removal of subagent tools. Those mechanisms
require a separately authorized, narrowly tested configuration change under I9 in
the full-product plan. Use supported controls; do not claim prose enforces runtime
permissions. Hooks must preserve STOP, owner-approval waits and legitimate blockers,
must not grant authority or auto-publish, and must not create a new task database,
review engine or unbounded continuation loop.

## UI Completion Standard

A UI feature is complete only when it has:

- Persistence appropriate to the feature
- Activity or audit evidence for consequential actions
- Defined non-happy-path behavior
- Accessible and recoverable error handling
- Acceptance tests
- Comparison with the relevant screenshot under `docs/design/mockups/`
- Responsive verification at relevant window sizes
- Independent QA verification

A static visual match without working behavior is incomplete. Working behavior
that materially contradicts the approved design is also incomplete.

## Security and Privacy Verification

Require independent Security/Privacy review only for capabilities involving:

- Local storage, folder authorization, recovery, or data deletion
- AI model selection, routing, prompts, or transmitted content
- Gmail or Calendar data and permissions
- Application behavior that reads, transmits, relocates, previews, exports, or
  persists owner or untrusted document content. Ordinary Markdown changes do
  not automatically require Security/Privacy review.
- Research providers or other external data sources
- Authentication, credentials, tokens, entitlements, or sandbox access

Do not weaken permissions, sandboxing, validation, authentication, or privacy
protections to make a feature work. Permission failures must produce actionable
recovery behavior instead of silent failure or permanent dead ends.

## Repository-Tool Prohibition

Do not invoke, search for, inspect, install, mention as a dependency, or wait on
`codex-governance`, including its skill, CLI, configuration, or any
`governance.yml` file.

Maintain delivery records and perform repository checks only with this
repository's ordinary files and tools.

## Release Radar Verification

- Follow test-first development for behavior changes and bug fixes.
- Use repository-native build, test, lint, and formatting commands verified
  from project configuration or documentation.
- Verify the changed behavior, its immediate integration boundary, the reported
  failure mode, relevant persistence and recovery behavior, and the applicable
  acceptance criteria.
- Verify applicable security boundaries directly; process evidence or reviewer
  opinion does not substitute for exercising the relevant protection.
- When UI inspection is available, verify the running application through
  accessibility state and screenshots and compare it with the relevant design
  reference.
- If runtime inspection is unavailable, report the limitation and do not claim
  that the interface was reproduced.

Compilation, static analysis, repository-index output, or the presence of a
required process does not prove runtime correctness.

<!-- release-radar-guidance:v2:start -->
## Release Radar tracking

This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

- Read `docs/catalog.json` and begin documentation discovery at `docs/README.md`. Follow generated local indexes before broad search and load only task-relevant controlling artifacts.
- The catalog owns documentation identity, lifecycle, authority, and navigation. `docs/delivery/progress.md` remains the durable delivery source of truth; the catalog and indexes never authorize or infer ticket or phase state.
- Under owner authorization, update the catalog, collection/index metadata, active references, and applicable checksums in the same change as any durable add, move, rename, supersession, closeout, restoration, or deletion. Preserve stable artifact IDs and never reuse retired IDs.
- Keep only active operational detail in `docs/delivery/progress.md`; move closed detail to `docs/delivery/archive/` and label it historical and non-authoritative. Place implementation plans in `docs/delivery/plans/` and controlling task briefs in `docs/delivery/task-briefs/`.
- Add no new content under `docs/superpowers/` during transition and never recreate it after cutover.
- Release Radar is the only SQLite writer. Never edit that database or repair a managed evidence path directly. Use supported read-only inventory and typed, audited evidence operations with exact artifact IDs and request identities.
- Managed operations require the exact authorized root and accepted repository ID, catalog version, and digest. Only explicit repository binding establishes a missing binding; only catalog acceptance advances an accepted snapshot. Treat a changed catalog as pending until Release Radar accepts its validated transition.
- Run the repository documentation check and read back the resulting repository and application state before completion. Do not claim completion while catalog, indexes, lifecycle, authority, references, applicable checksums, evidence resolution, or application readback disagree. Preserve exact requests across uncertain outcomes.
- Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state. Repository-local rules outside this block may narrow this contract but must not weaken or duplicate it.
<!-- release-radar-guidance:end -->
