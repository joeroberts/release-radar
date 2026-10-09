# Release Radar documentation

Current work, acceptance criteria, and delivery results belong to the owning
[GitHub issue](https://github.com/joeroberts/release-radar/issues). Canonical
product specifications and architecture decisions are maintained in the
[Release Radar Wiki](https://github.com/joeroberts/release-radar/wiki).

For Release Radar development assignments and task-relevant skill routing,
start with the repository [agent instructions](../AGENTS.md) and the Wiki's
[RR Development Delegation Model](https://github.com/joeroberts/release-radar/wiki/RR-Development-Delegation-Model).
The owning issue or assignment records exact delivered skill revisions and
actual discovery or invocation results; this documentation index does not prove
that a reusable skill is installed or available in the current session.

Repository documentation retains the current [delivery snapshot](delivery/progress.md)
and repository-owned [design references](design/README.md). For proposed
whole-product work, use the published
[full-product architecture and delivery plan](https://github.com/joeroberts/release-radar/wiki/Full-Product-Architecture-and-Delivery-Plan).

## Development documentation CI routing

[`development-documentation.yml`](../.github/workflows/development-documentation.yml)
always creates its `validate` job for pull requests to `main` and pushes to
`main`. It uses the checked-in
[`collect_development_changed_paths.sh`](../script/collect_development_changed_paths.sh)
and [`classify_development_changes.py`](../script/classify_development_changes.py)
helpers to select documentation-owned checks from the complete diff.

| Changed input | Selected documentation checks |
| --- | --- |
| `docs/**` or a root Markdown document | Documentation validation |
| Documentation-checker implementation or focused tests | Documentation validation and checker tests |
| ADR-checker implementation, tests, or fixtures | Documentation validation and ADR-checker tests |
| Workflow or routing-helper changes | Routing contract tests |
| Mixed changes | Union of applicable checks |
| Application, build, dependency, runtime-resource, or marketplace input | No documentation check solely for that input; app/build CI remains pending [#119](https://github.com/joeroberts/release-radar/issues/119) |

The classifier treats unknown, malformed, empty, or unavailable diff input as
a visible fail-closed fallback and runs all documentation-owned checks. The
collector uses `--no-renames`, so deleted paths and both sides of a rename are classified.
For an unexpected run or skip, first inspect the workflow's **Classify changed
paths** JSON output: a non-null `fallback_reason` means broad validation was
intentional; otherwise compare the reported categories with the table. The
`validate` job itself should not be absent for supported PR/push triggers.
An application-only change may pass `validate` while #119 lacks an app-build
gate; that is routing behavior, not application verification.

## Development skill guidance

Read only the entry relevant to the current ticket and assigned role. The
[AGENTS task router](../AGENTS.md#development-skill-selection) selects methods;
the discovered skill supplies its operating method and the linked Wiki role
remains Release Radar project authority.

Use only the skills relevant to the current ticket and assigned role. Do not
load the complete skill suite for a simple task. A skill must be present in the
current host's discovered skill catalog before it is described as available;
source files, an installation request, or another session's result do not prove
current discovery or invocation. If an assigned skill is missing, report its
name, expected canonical source and discovery location, and the effect on the
work instead of claiming success or manually reproducing its algorithm.

Reusable development-method and role skills are canonically authored in
[`joeroberts/ai-tools`](https://github.com/joeroberts/ai-tools) under
`integrations/codex/skills/<name>/`. For the owner-authorized local rollout,
their user discovery links are `~/.codex/skills/<name>` and target the stable
ai-tools checkout, never a disposable worktree or installed cache. Record the
exact delivered source revision and verified discovery location in the owning
issue or assignment. Release Radar-specific skills remain tracked directly in
this repository under `.agents/skills/<name>/`; their files and relative
resources must resolve from a fresh checkout or worktree. Do not copy reusable
skills into Release Radar merely to expose them. The
[official Codex skill guidance](https://learn.chatgpt.com/docs/build-skills)
documents repository discovery from `.agents/skills` and following symlinked
skill folders; the owner-selected user endpoint for this rollout remains a
host-specific arrangement that must be verified on the target host.

For every selected skill, the assignment names its invocation condition,
required project inputs and target context, supported command or project check
when one exists, expected result, failure response, and result destination.
Instruction-only skills have no fictitious universal command: use the
project-owned checks relevant to their output and identify what remains a
judgment. Skill loading does not create a role task, configure its model, grant
authority, satisfy independent review, or turn a successful tool call into
permission to mutate.

### Delivered role routing

Use these delivered entry points only under their listed conditions. Browser
and Python methods apply to actual browser/Python work, not native app behavior.

| Entry point | Invoke with | Execution, result and failure response |
| --- | --- | --- |
| `progress-handoff` | An authorized replacement of the existing progress snapshot; exact repository root, target, candidate, evidence, limits and validators. | Use the deterministic pre-write and saved-file commands below. Return the resolved target, actual outcomes and next owner; retain the prior snapshot when the proposed check fails. |
| `start-resume-work` | An interrupted, compacted or handed-off authorized ticket; repository, worktree, owning issue, expected candidate, endpoint, current owner direction and existing handoff. | Run the bundled read-only inspection below before relying on the candidate. Reconcile its observation with current authority and return reusable terminal evidence, open dependencies and one next action in the existing issue or handoff. A mismatch, failed query or unavailable record remains unresolved; do not reset the checkout or begin dependent work to hide it. |
| `github-issue-creation` | A requested new issue or native issue relationship; exact repository, issue level, outcome and preserved requirements, governing issue-standard source and encoded rules, existing taxonomy, supplied hierarchy/dependencies/milestone/Project values and current publication authority. | Use the bundled JSON procedure below to draft and validate before publication. Publish only with exact mutation authority, then compare saved identity, body, metadata, relationships and Project values independently. Return the URL and separate operation/readback outcomes in the existing owning record; validation, a create response or partial success is not blanket success. |
| `completion-cleanup` | A delivered or explicitly superseded ticket with its outcome, criteria, authorized endpoint, exact cleanup authority and exclusions, repository/worktree/candidate, delivery evidence, named branches, tracking refs, worktrees, artifacts and role tasks, plus required recovery resources. | Run the bundled read-only inspector below before cleanup. It inventories only named resources and always reports `mutation_eligible: false`; determine delivery, ownership, uniqueness and preservation separately. Perform only individually authorized exact operations with readback, retaining dirty, shared, ambiguous or still-needed resources and reporting unresolved cleanup rather than broadening or forcing it. |
| `systematic-debugging` | One concrete unexplained or recurring failure; symptom and expected behavior, exact candidate/environment/input, available diagnostics, owner-data constraints, current authority and intended handoff. | This instruction-only method uses the project's existing commands for bounded reproduce, localization, competing hypotheses, least-impact experiment, correction and regression/recovery evidence. Record observations separately from causal judgment, retain intermittent uncertainty and stop materially identical attempts that add no evidence. Missing safe data, access or capability narrows the result; it does not authorize owner-data collection, broader experiments or retry machinery. |
| `acceptance-verification` | A complete outcome and criteria, exact candidate and target, project check recipes, evidence destination and check ownership. | Use the smallest relevant project-owned checks and return criterion statuses with observed evidence. In RR, QA owns test execution. Missing inputs remain `Blocked` or `Not Run`; no universal helper or successful unrelated command supplies acceptance. |
| `decision-investigation` | One bounded rationale, approval or applicability question; named anchor, repository/provider and revision, governing authority and time perspective. | This read-oriented, instruction-only skill uses narrowly resolved project Git, provider and decision tools rather than a packaged helper. For RR ADR evidence, compose it with the repository `adr-management` skill and consume only that skill's verified pinned bytes. Return cited facts, intent, demonstrated behavior, inference, conflicts and unknowns; stop with a qualified unresolved result when evidence or authority is missing. |
| `pr-reviewer` legacy guidance | An independent Reviewer/Auditor assignment for a PR, branch or diff; exact source and destination refs, owning criteria, actual candidate/environment and relevant consequential boundaries. | Use the canonical ai-tools guidance and merge-base review procedure, not a global skill claim. Run an existing or focused real candidate-specific check when a consequential safety assumption is observable; failed, unavailable or inconclusive evidence remains unverified. Return Required, Optional and Out-of-scope findings with candidate metadata, actual checks and limitations; passing evidence grants no mutation authority. |
| `chief-architect` | A named public-contract, persistence, component-boundary or accepted-decision question with the affected consumers, constraints and decision endpoint. | This instruction-only role method returns alternatives and a qualified recommendation using relevant project checks. It does not accept a decision or implement it; missing boundary evidence remains unresolved. |
| `feature-architect` | An approved bounded feature whose component, state, data-flow, failure or recovery design is unsettled; complete criteria and exclusions, exact source/consumers, established contracts, design constraints, architecture context and authorized design endpoint. | This instruction-only role method returns whole-journey ownership, normal and exceptional states, coherent implementation slices, observable QA seams, limitations and handoffs. It does not create a task or settle public contracts, persistence or cross-component decisions; name those conflicts for Chief Architect and continue only where independent design remains possible. |
| `senior-macos-native-software-developer` | Substantive macOS SwiftUI/AppKit behavior; exact candidate, deployment target, project shape, reproduction/design, runtime availability and project ownership rules. | This instruction-only role method implements or diagnoses native behavior and hands the exact candidate and scenarios to QA/CI/CD/review. It has no generic helper; unavailable runtime evidence stays unverified, and packaging, signing, installation and release remain with CI/CD. |
| `senior-dba` | A concrete schema, query, index, transaction, migration, integrity, locking, recovery or database-performance problem; engine/version, schema and application path, exact candidate/scenario, data classification, compatibility commitments, safe fixtures and authorized environment. | This instruction-only role method uses existing project and engine checks, returning observed evidence separately from inference plus integrity, compatibility, failure/retry and recovery implications. Missing inputs narrow or block the result. QA owns RR fixtures and test execution, architecture owns persistence-contract decisions, and only Release Radar writes its SQLite store. |
| `senior-software-developer` | An authorized application or tooling feature, defect correction or bounded refactor; complete outcome, criteria and exclusions, exact candidate and endpoint, reproduction/expected behavior, relevant contracts, dirty-work context and project ownership. | This instruction-only role method localizes the implementation boundary, makes the smallest coherent change covering implicated normal/error/recovery behavior, preserves contracts and unrelated work, and hands the exact candidate to QA, review and delivery. It is not an architecture-only, QA, CI/CD or cleanup role; missing inputs and checks remain explicit rather than invented or promoted to completion. |
| `senior-qa-engineer` | A bounded behavior change or defect needing verification; complete criteria, exact candidate and target identity, environment, design/risk inputs, existing tests/fixtures, runtime access, allowed test data, ownership and evidence destination. | This instruction-only role method maps every criterion to expected and actual observations and a `Passed`, `Failed`, `Missing`, `Blocked` or `Not Run` result, then exercises only relevant behavior and integration, failure, persistence, recovery, UI or accessibility boundaries. QA owns RR tests, fixtures and execution; it does not implement, independently review or authorize delivery, and a target mismatch or unavailable runtime stays unverified. |
| `ux-architect` | A bounded user-facing journey, guidance or presentation change; user job and criteria, approved constraints/design, representative states, supported platforms/sizes, exact candidate and available runtime/design evidence. | This instruction-only role method keeps observed, proposed and unverified claims separate while assessing navigation, language, states, keyboard/focus, accessibility, responsive presentation and recovery. It returns Required, Optional and Unresolved findings without inventing design approval or runtime evidence; backend-only work does not select it, and source or mockups alone do not prove delivered interaction. |
| `senior-frontend-software-developer` | An authorized substantive browser interaction or diagnosis; outcome and criteria, exact candidate/endpoint, framework/runtime, approved design, component/API/state contracts, browsers/viewports, reproduction, runtime access and role ownership. | This instruction-only role method implements the smallest coherent browser change, applicable loading/empty/validation/error/cancellation/recovery states, established stale-request handling, keyboard/focus/accessibility and responsive behavior while preserving consumer and trust contracts. It is not a native, hosting, deployment, QA or CI/CD role; observed browser behavior remains separate from source inference and the exact candidate goes to QA and review. |
| `senior-software-security-engineer` | A concrete security design, changed trust boundary or supplied finding; exact candidate/question, assets and data classification, actors and grants, trust crossings, authorized environment/actions and safe evidence or fixtures. | This instruction-only role method examines only relevant security boundaries, classifies conclusions as demonstrated, plausible or unknown, and recommends the smallest effective correction with validation and residual risk. It does not start an unauthorized scan, live exploit, secret access, owner-data mutation or destructive action; specialized security workflows are selected only when their trigger and authority fit. |
| `senior-ci-cd-engineer` | A bounded GitHub Actions, check, runner/cache, build, packaging or explicitly authorized delivery path; exact repository/revision/version, event trust, runner/permissions, native commands and owners, artifact/consumers and endpoint. | This instruction-only role method preserves least privilege and exact source/artifact identity across event, checkout, cache, artifact and publication boundaries, reporting configured, built, installed, running and verified as separate observed states. It does not own application work or QA test design, start a release for documentation, infer credentials or publishing authority, or duplicate/overwrite artifacts to cure partial delivery. |
| `senior-python-developer` | An authorized substantive Python or FastAPI implementation or diagnosis; outcome, candidate/reproduction, exclusions and endpoint, pinned Python/framework/server/dependency versions, affected route/model/dependency/lifespan/persistence/auth contracts, tooling and expected normal/error/cancellation/cleanup behavior. | This instruction-only role method traces the actual request and resource lifetime, preserves API/error/auth contracts, and makes the smallest pinned-runtime-compatible correction for relevant validation, blocking/async, dependency, lifespan or failure behavior. Plain Python does not acquire FastAPI or a service scaffold; missing runtime evidence stays unverified, and QA owns focused concurrency, cleanup, override/lifespan and authenticated-failure checks. |
| `rds-change-workflow` | A UI change needs shared RDS tokens, components or visual behavior; exact consumer pin, current library API, smallest shared capability, affected authorized consumers and delivery endpoints. | Inspect supported customization first; ordinary app composition alone does not require library work. Route a shared gap through the discovered skill's library task/worktree, review and consumer-adoption workflow. Preserve RDS ownership of shared capabilities and app ownership of product composition/window policy; carry current authorization explicitly, and do not infer library or consumer mutation authority from routing. |
| `wiki-documentation` | Substantive implementation-plan or product-specification authoring, revision or evaluation, including owning indexes, navigation and lifecycle; owning ticket, operation, canonical document, source evidence, project conventions and authorized endpoint. | Select the skill's applicable plan/specification and maintenance references. Preserve proposed, approved, implemented and verified distinctions; return canonical results, actual checks, Required/Optional/Out-of-scope findings and unresolved decisions. Drafting and evaluation grant no publication authority. Route every protected RR ADR operation through `adr-management`. |
| `pushover-notifications` | An actionable owner decision, approval or intervention under the AGENTS owner-attention rule; ticket/task context, concrete next action and the discovered helper. | Follow the skill's send-time credential requirements, normal priority, setup/change dry-run and sanitized failure handling. Never disclose credentials or pass secrets on the command line; do not retry automatically or treat failure as owner receipt. Send one clear actionable notification for an unchanged condition and continue independent authorized work. |

### Supported execution recipes

Record actual source revision, installation, host discovery, invocation and
behavioral result as separate facts in the owning issue or assignment. A merged
source, closed implementation issue, valid discovery link or successful
invocation establishes only that named state; none substitutes for the others.

Before entering any skill-folder subshell below, resolve every file-system
input against the assignment checkout and store its absolute path. In
particular, `$issue_spec`, `$issue_spec_with_url`, `$recovery_spec`,
`$repository`, `$worktree`, and every cleanup artifact, cleanup worktree and
task-observation file must be absolute. Do not pass a caller-relative path after
`cd` changes the resolution base.

For `github-issue-creation`, run the supported subcommand from its discovered
skill folder. Draft and validation are non-mutating; live operations require
the exact authorized input:

```sh
(
  cd ~/.codex/skills/github-issue-creation
  python3 scripts/issue_ops.py draft --input "$issue_spec" --transport fixture
  python3 scripts/issue_ops.py validate --input "$issue_spec" --transport fixture
)
```

Each subcommand prints one JSON result. Input or validation failure exits `2`,
a completed operation exits `0`, and a structured failed or unresolved live
operation exits `3`. After successful validation, run only the applicable
authorized live operation: `publish --input "$issue_spec" --transport gh` for
initial creation, `readback --input "$issue_spec_with_url" --transport gh` for
an independent later comparison, or
`recover --input "$recovery_spec" --transport gh` for bounded partial-failure
recovery. Invoke each from the same discovered skill folder. `publish` and `recover` require
`publication_authorized: true`; recovery also requires the known same-repository
issue URL and prior operation record and never creates another issue. Treat
every operation and readback comparison separately, and preserve failed or
unresolved relationships, Project fields, access or identity instead of
retrying creation or broadening permissions.

For `start-resume-work`, run its helper from the discovered skill folder with
the exact assignment inputs:

```sh
(
  cd ~/.codex/skills/start-resume-work
  python3 scripts/inspect_work_state.py \
    --repository "$repository" \
    --worktree "$worktree" \
    --issue "$owning_issue" \
    --expected-candidate "$expected_candidate" \
    --authorized-endpoint "$authorized_endpoint"
)
```

The helper prints one read-only JSON observation. Inspect `failed_queries` and
`comparison.match`; process exit alone does not establish a usable candidate,
current authority or an unblocked next action. Resolve mismatches and failed or
unavailable queries through current project evidence before dependent work.

For `completion-cleanup`, run the inspector from the discovered skill folder
against the exact assigned resources. Add only the repeatable resource options
that are actually in scope: `--local-branch`, `--remote-branch remote:name`,
`--remote-tracking-ref`, `--worktree`, `--artifact`, `--task`, and paired
`--task-observations` as applicable. When provider delivery evidence is needed,
add `--delivery-evidence "$delivery_evidence"`, where `$delivery_evidence` is
the absolute path to provider JSON. Omit that option when the exact
`--delivered-ref` is the applicable delivery evidence.

```sh
(
  cd ~/.codex/skills/completion-cleanup
  python3 scripts/inspect_cleanup.py \
    --repository "$repository" \
    --owning-issue "$owning_issue" \
    --authorized-endpoint "$authorized_endpoint" \
    --candidate-ref "$candidate_ref" \
    --delivered-ref "$delivered_ref" \
    --artifact "$artifact"
)
```

Exit `0` means the requested observations were conclusive, which may include
`not_delivered`; it does not authorize cleanup. Exit `2` means an observation
is unresolved, and exit `64` means the invocation is invalid. Never convert the
inspector's JSON into a default delete list: it deliberately keeps
`mutation_eligible: false`. Use literal resource identities, no globs, broad
prune, `git clean`, force reset or destructive checkout. Report the candidate,
delivery proof, retained durable and recovery resources, each exact cleanup and
readback, unresolved state, and whether the result is complete, incomplete,
blocked, dirty, shared or pending approval. Archive role tasks only after the
owning issue is observed closed and that exact archival is authorized.

The delivered `pr-reviewer` capability remains legacy guidance at
`integrations/codex/skills/pr-reviewer/pr_reviewer.md` in the canonical
ai-tools checkout; it has no `SKILL.md` or global discovery installation. Do
not claim catalog discovery or reconstruct it under `~/.codex/skills`. Resolve
`ai_tools_root` to the absolute stable checkout recorded by the assignment. If
a cleanup review has the same fixed-entry expiration assumption as the bundled
example, the Reviewer may run its real co-located fixture:

```sh
python3 "$ai_tools_root/integrations/codex/skills/pr-reviewer/tests/cleanup_assumption_fixture.py" \
  --implementation correct
```

Exit `0` with concise JSON shows the fixed expired entries were removed and the
active entry retained. The same command with `--implementation defective`
exits `1` and reports a Required active-data-deletion finding;
`--implementation unavailable` exits `2` and leaves the assumption unverified.
This is a worked candidate-specific example, not a mandatory review tier or a
substitute for the RR Reviewer/Auditor role, its current criteria or other
applicable project checks.

When an authorized Release Radar handoff uses `progress-handoff`, validate the
complete proposed bytes before replacing the existing snapshot:

```sh
swift "$repository_root/script/check_development_docs.swift" --progress-stdin < "$proposed_content"
swift "$repository_root/script/check_development_docs.swift" --root "$repository_root"
```

Resolve `proposed_content` and `repository_root` for the exact worktree. The
first command must succeed before the single snapshot is replaced; after the
write, read back the target and run the second command. On an unavailable or
failed check, leave the prior snapshot unchanged when it has not yet been
replaced and report the exact failure. The validator deterministically enforces
the byte and line limits; evidence selection, content accuracy, authority, and
the next action remain judgment. Delivery Management owns the snapshot, and
current results belong in the owning issue rather than a new tracker.

<!-- release-radar-docs:v1:start -->

## Collection: docs

- Path: [docs](.)
- Purpose: Release Radar documentation, current authority, and retained history
- Allowed contents: Catalog and navigation indexes; Design and delivery collections
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [c48466fb-a4fd-4f9e-96bf-967dfa173216](README.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| c48466fb-a4fd-4f9e-96bf-967dfa173216 | [docs/README.md](README.md) | collectionIndex | supporting | active | none | none |

### Children

- [delivery](delivery) — leaf; Current delivery status
- [design](design/README.md) — indexed; Repository-owned visual references

## Leaf collection: delivery

- Path: [docs/delivery](delivery)
- Purpose: Current delivery status
- Allowed contents: Current progress ledger
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [450e84de-703b-4dcd-ad1a-7fddfee0d1d9](delivery/progress.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 450e84de-703b-4dcd-ad1a-7fddfee0d1d9 | [docs/delivery/progress.md](delivery/progress.md) | document | controlling &#40;delivery.current-state&#41; | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
