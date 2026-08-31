# Release Radar Agent Instructions

## Scope and Controlling Artifacts

These instructions apply to the entire repository.

Treat the user's explicit request and the approved project artifacts as the
controlling sources for Release Radar. Current artifacts include:

- `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` for the approved MVP
  plan and task boundaries
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

## Independent Delivery Model

Release Radar uses independent agents as its default delivery model. The
primary agent coordinates scope, integration, and handoffs; it does not replace
the independent planning, architecture, TPM, QA, review, security, or delivery
management roles.

| Role | Responsibility |
| --- | --- |
| Planning agent | Converts approved product and architecture artifacts into granular, test-first task briefs with explicit dependencies and acceptance criteria. |
| Architect agent | Owns architecture decisions, data and security contracts, interfaces, and ADRs. It does not approve its own implementation. |
| TPM agent | Owns roadmap sequencing, dependency gates, risks, milestone readiness, and scope control. |
| QA/test agent | Defines fixture and test strategy before implementation and independently verifies every slice and milestone against acceptance criteria. |
| Delivery manager agent | Maintains the progress ledger, opens only dependency-safe work, records decisions and evidence, and escalates blockers. |
| Implementer agent | Delivers one bounded vertical slice and its targeted tests. |
| Code reviewer agent | Independently reviews one implementation task for specification compliance, regressions, and code quality. |
| Security/privacy verifier | Independently verifies high-risk capabilities, including local storage and recovery, AI routing, Gmail and Calendar integrations, documents, and research providers. |

An agent may not review, approve, or independently verify its own
implementation.

## Execution Authorization Boundaries

- “Consider,” “discuss,” “evaluate,” or “recommend” authorizes no tool use or
  changes unless the owner explicitly requests inspection.
- Eligibility does not constitute authorization.
- `STOP` immediately prohibits further tools, writes, tests, subagents, Git
  operations, Release Radar mutations, and external actions.
- Only an explicit owner resume naming the task and authorized action clears a
  stop. “Approved” alone does not resume stopped work.
- After the first failure of a mechanism, permit one bounded diagnosis and
  correction only when implementation remains authorized.
- A second failure of the same mechanism stops the task.
- A bounded fix receives only affected-role re-review; it does not restart the
  full review matrix.
- After implementation begins, returning to planning requires explicit owner
  authorization.

## Execution Gates

For each implementation slice:

1. A Planning agent produces a granular, test-first task brief.
2. The Architect, TPM, QA/test agent, and Delivery Manager independently review
   the plan before implementation begins.
3. The TPM and Delivery Manager release only the next eligible,
   dependency-safe task.
4. A fresh Implementer completes the bounded task and its targeted tests.
5. A separate Code Reviewer and QA verifier review the completed task.
6. The Architect reviews architectural effects. Record approved deviations
   through the repository's ADR process.
7. The TPM and Delivery Manager record completion evidence and open the next
   dependency-safe task.
8. At each milestone, conduct independent architecture, security/privacy, and
   QA reviews before proceeding.

Keep the process proportional to the task, but do not bypass role independence
or a required approval because an implementation appears straightforward.

## Task Briefs

Every implementation task brief must include:

- Objective and user-visible outcome
- Controlling product and design references
- Explicit in-scope and out-of-scope boundaries
- Dependencies and release gate
- Affected subsystem and anticipated files
- Data, persistence, security, and privacy implications
- Test fixtures and test strategy defined before implementation
- Happy-path and non-happy-path behavior
- Activity or audit evidence requirements
- Acceptance criteria
- Required independent reviews
- Completion evidence expected in the progress ledger

Do not begin implementation from a vague roadmap label alone.

## Progress Ledger

Use `docs/delivery/progress.md` as the durable delivery source of truth. Do not
create a competing ledger.

For every task or milestone, record:

- Status and dependency-gate state
- Assigned independent role or agent
- Completed implementation
- Test commands and results
- QA verification evidence
- Code-review outcome
- Architecture review and ADR references
- Security/privacy verification when applicable
- Product and mockup acceptance evidence
- Open blockers and risks
- Scope or sequencing decisions
- The next eligible task

Code or compilation alone does not make a task complete.

## Agent Lifecycle and Concurrency

- Treat independent agents as ephemeral. After receiving and durably recording
  an agent's requested output, release it when the environment provides a
  lifecycle control; do not keep it assigned for unrelated work.
- Do not reuse an Implementer as the reviewer, QA verifier, architecture
  approver, or security/privacy verifier of its own work.
- Do not run parallel agents against the same subsystem, files, or shared
  mutable state without an explicit integration plan.
- Parallelize only work with clearly separated ownership boundaries.
- The primary agent remains responsible for coherent integration and resolving
  conflicting recommendations.

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

Require independent security/privacy verification for capabilities involving:

- Local storage, folder authorization, recovery, or data deletion
- AI model selection, routing, prompts, or transmitted content
- Gmail or Calendar data and permissions
- Documents, attachments, previews, or exports
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
- When UI inspection is available, verify the running application through
  accessibility state and screenshots and compare it with the relevant design
  reference.
- If runtime inspection is unavailable, report the limitation and do not claim
  that the interface was reproduced.

Compilation, static analysis, repository-index output, or the presence of a
required process does not prove runtime correctness.
