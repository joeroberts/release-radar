# Release Radar Agent Instructions

## Standalone Repository Development

This repository is no longer tracked or governed by the Release Radar application.
Use ordinary Codex tasks, Git worktrees, repository-native checks and the GitHub
CLI (`gh`). GitHub issues hold the work list and task results.

Development does not require RR registration, phase or ticket transitions,
Delivery Goal assignment, catalog acceptance, managed worker preparation,
execution hooks, or the release-radar/shared-execution skills. Do not re-onboard
this repository or restore those requirements without explicit owner direction.
Existing plans, briefs, catalogs and delivery records remain reference material;
their former RR execution procedures do not govern this repository. Preserve
applicable product requirements and accepted architectural decisions.

Agents may perform authorized work directly. Use independent review for material
changes without requiring standing roles or an RR-managed assignment. No mandatory
task brief, ledger mutation or app-state synchronization is needed to start or
finish repository work.

## Scope and Controlling Artifacts

These instructions apply to the entire repository.

Treat the user's explicit request and the approved project artifacts as the
controlling sources for Release Radar. Current artifacts include:

- `docs/design/release-radar-ticket-tasks-design.md`
  for the delivered ticket-task product contract
- `docs/delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md`
  for whole-product dependencies and assessed future direction; preserve its
  distinction between approved inclusion, proposed contracts and implementation
- `docs/architecture/ADR-007-proportional-delivery-validation.md` as the record
  of the operating-model and proportional-validation decision; `AGENTS.md`
  contains the operative agent rules
- `docs/design/agent-driven-delivery-dashboard-design.md` and
  `docs/design/mockups/` for product and visual design
- `docs/architecture/ADR-001-release-radar-boundaries.md` for architecture,
  data, integration, sandbox, and signing boundaries
- `docs/brand/README.md` for the approved product identity
- GitHub issues for current work, status and verification;
  `docs/delivery/progress.md` is retained delivery history

Do not silently override approved artifacts with assumptions, generated plans,
repository indexes, or implementation convenience. Treat `.codegraph` output
as a navigation aid and verify consequential findings against the current
source, tests, configuration, application bundle, or running app as
appropriate.

Accepted ADRs are immutable decision records. Current implementation
specifications belong in the owning mutable design documents; operative agent
rules belong in `AGENTS.md`; current authorization comes from the owner and
current work is recorded in GitHub issues. Plans, briefs, skills, reviews and implementation
assignments cannot authorize editing an accepted ADR. Routine specification
maintenance must preserve accepted ADR text. A future architectural change
requires a separately authorized decision; it is not permission to amend an
accepted ADR.

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
- Record necessary deviations and their rationale in the owning mutable design
  document. A deviation requiring an architectural change needs a separately
  authorized decision; preserve accepted ADRs.

## Durable Artifact Placement

Paths under `~/.codex`, `/tmp`, and thread-scoped visualization directories are
temporary scratch space only. They are never the source of truth for Release
Radar deliverables.

- Persist durable Release Radar design documents under `docs/design/`.
- Persist approved Release Radar mockups under `docs/design/mockups/`.
- Preserve human-authored historical drafts, role reports, review packages, and
  superseded briefs under `docs/delivery/archive/` when the owner requests
  archaeological retention. Archive content must be labelled historical and
  non-authoritative; it does not determine current work or sequencing.
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

## Standing Owner Authorization: Local Release Delivery

The owner explicitly authorized this standing workflow on September 12, 2026
and requested that it persist beyond the current session. After an authorized
batch of Release Radar app changes passes applicable checks and independent
review, complete these steps without asking for the same approval again:

1. Commit the scoped changes.
2. Advance the semantic patch version for ordinary fixes (for example, 0.1.12
   to 0.1.13), keeping required app/package version metadata consistent.
3. Create the matching annotated local Git tag, using the `vX.Y.Z` convention,
   on the release commit. Preserve accurate build-source provenance and never
   move or overwrite an existing release tag.
4. Build and verify `ReleaseRadar-X.Y.Z.dmg` using the established signing and
   packaging workflow, and provide the versioned installer in Downloads.
5. Install that verified version in `/Applications/ReleaseRadar.app` and verify
   the installed version and package identity.

Existing versioned DMGs serve as rollback copies. Do not create extra app backup
archives or duplicate rollback copies. Preserve existing installers unless the
owner separately authorizes their removal.

This authorization applies to local delivery of completed app changes, including
the bookmark and Help corrections destined for 0.1.13. It does not turn planning,
documentation-only work, or an intermediate task into a release. Coordinate one
release owner after the intended batch is complete rather than packaging every
commit or creating competing installations.

The owner authorizes publishing the existing annotated `vX.Y.Z` tag to `origin`
as part of each completed local Release Radar release. After the tag is created,
push that exact tag and verify that its remote peeled commit equals the local
tag's commit; never move or overwrite a release tag. Branch pushes, PR creation,
merges, public releases and notarization retain their separate authorization
boundaries. Do not interpret installation approval as permission for unrelated
project-data or configuration changes. An explicit STOP or a later narrower
owner instruction takes precedence; legitimate runtime permission gates must
still be respected. Report a concrete failure or missing permission rather than
claiming completion or repeating an already granted approval question.

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
