# Current documentation and execution enforcement plan

Status: proposed; owner requested this plan on 2026-09-13. This document does not authorize implementation, task dispatch, configuration changes, or application operations. It supplements the [full-product plan](2026-09-06-full-product-architecture-and-delivery-plan.md); [progress](../progress.md) remains the source of current authorization and delivery state.

## Intended outcome

An agent starting current work receives current, applicable instructions without stale assignments competing for authority. Historical documents remain available for an explicit historical question. Mechanical restrictions are enforced by tested controls wherever the host can actually enforce them. The owner should not have to reconstruct assignments or repeatedly correct task roles, scope, and permissions.

The concern being addressed is confusion caused by stale information in the reading path. Establishing that it caused a previous failure is not a prerequisite for fixing that exposure.

This plan has two connected workstreams: current documentation and default retrieval; execution controls and their adoption. Fixing documentation can proceed even if a proposed runtime control proves unsupported.

## Existing decisions and exact scope

Outcome 1 was merged in PR 58 at `d78fef9f308f5e2590b18fd9b6de8360ff76be8f`. Its operative-authority corrections are the starting point, not work to repeat. Accepted ADRs remain unchanged. AGENTS.md supplies operative instructions, mutable designs carry current specifications, and progress carries current authorization and sequencing. The ADR-006 clarification in the full-product plan distinguishes accepted M1 direction from excluded procedures and later additions.

The remaining problem includes where agents encounter those distinctions. The current root index presents all seven ADRs as active controllers. The catalog contains 81 task-brief documents, including 68 completed/non-authoritative records, nine active/supporting documents, three completed/supporting documents and one proposed/supporting document. An inventory is useful for discovery, but it is not an appropriate instruction bundle for every task. A supporting runbook may still be useful after its original delivery assignment ends; a completed brief may contain requirements that still need a current specification home.

The following work is explicitly included in the proposed delivery scope:

- Identify stale assignments, obsolete procedural requirements, misleading status, partial supersession, and current requirements stranded in historical briefs.
- Correct operative entry points, current specifications, catalog classifications, navigation and active references together. Put applicable authority qualifications at the point of entry, including ADR-006's limited acceptance and ADR-007's relationship to current AGENTS.md.
- Remove directions to edit accepted ADRs wherever they remain operative. Record architectural changes through separately authorized new decisions; preserve accepted ADR bytes.
- Reconcile closed assignment language and current status without discarding continuing product requirements, compatibility constraints or useful runbooks.
- Test targeted host controls for document exposure, protected writes, assignment dispatch and authorized endpoints. Distinguish prevention from detection for each control.

No blanket declaration that every old ADR or brief is superseded is permitted. No historical document is deleted. No app database, managed evidence, installed application, unrelated repository, or global configuration changes are included by implication.

## What the research supports

| Evidence | Finding and limitation | Decision for this plan |
| --- | --- | --- |
| [Stripe Minions](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2) and [OpenAI harness engineering](https://openai.com/index/harness-engineering/) | Production accounts favor deterministic steps, scoped context, ordinary checks and constrained agent work. They are vendor case studies, not controlled proof that this repository needs a new orchestration engine. | Use existing task tools and checks; move genuinely mechanical decisions out of prompt rewriting. |
| [Agent-C](https://adharshkamath.github.io/papers/agentc.pdf) | Tool-call constraints substantially improved policy conformance in simulated retail and airline tasks. Correct policies and trustworthy state remain prerequisites; conformance does not prove that a human approved an action. | Validate actions against observed task state and explicit owner authorization. An agent-written approval reference is insufficient. |
| [Evaluating repository context files](https://arxiv.org/html/2602.11988v2) | More instructions increased activity and cost without a consistent improvement in task resolution. This is not a direct experiment on our stale-document problem. | Prefer a small applicable reading set over expanding every prompt or reading every historical brief. |
| [SpecKitAgents](https://arxiv.org/html/2604.05278v1) | Small measured quality gains came with longer runs; human preference evidence was mixed. | Keep briefs concise and tied to the actual outcome. Do not introduce a large specification pipeline. |
| [Codex hooks](https://learn.chatgpt.com/docs/hooks) and [rules](https://learn.chatgpt.com/docs/agent-configuration/rules) | Supported calls can be intercepted, but coverage is not universal. Continuing command input and special tool paths require particular attention; post-action checks cannot prevent an action already taken. | Verify the installed host and every claimed route before relying on a control. Report uncovered routes explicitly. |

These findings support a bounded implementation and measured pilot. They do not establish that a structurally valid prompt guarantees correct scope, genuine authorization, or future obedience.

## Whole-workflow target design

The outcome is a complete workflow whose current knowledge, assignments, action permissions and completion evidence agree. The delivery stages below build that end state; a successful narrow pilot is not completion of the whole fix. Research informs the following architectural recommendation: keep judgment in agents, put mechanical selection and action checks in deterministic code, and ground both in sources the executing agent cannot silently redefine.

### 1. Current knowledge and retained history

Use the existing catalog as the document identity and lifecycle source. Review the full relevant documentation estate: design documents, specifications, plans, task briefs, runbooks, evidence instructions and entry pages. Classifying only task briefs is insufficient. Separate current specifications and reusable operating references from obsolete assignments and designs. Preserve accepted ADRs unchanged, including any later superseded decision records, with their current applicability explained outside the immutable text.

Move eligible historical material out of active documentation collections into the existing archive, preserving identity, provenance, links and supported lifecycle transitions. Where physical movement is inappropriate, exclude it from the default selection just as explicitly. Archive labels alone are insufficient. Default document search, recursive retrieval, prompt assembly and automatic link expansion must all use current-work selection. Historical results require a deliberate historical lookup and retain their qualification when returned. Full catalog inventory remains available for administration, without becoming an automatic context payload.

A catalog-driven current-document selector supplies the authorized task's references and necessary content. It consumes existing metadata; it does not maintain a second catalog. Its selection is inspectable. If an unrestricted shell can bypass the selector, the host must restrict that route for an enforced reading boundary. Until such coverage exists, report the exact remaining accidental-read exposure. Do not claim an archive on the same readable filesystem is isolated merely because ordinary links omit it.

### Required isolation design: storage, access and return path

Owner clarification: historical documents must not remain directly readable by routine delivery agents. The proposed architecture therefore uses isolated task workspaces. A same-user worktree plus search exclusions does not satisfy this requirement. This recommendation supersedes the earlier archive-only/default-search proposal; it is not installed behavior.

**Storage.** The existing canonical Release Radar repository remains the durable store for current documents, accepted ADRs and retained history. Its existing archive can continue holding historical records. No new cloud service, history database or second archive repository is proposed. The separation is between that canonical store and the execution environment: routine workers cannot mount, traverse or read the canonical repository, its Git object database, sibling worktrees, session transcripts or cached copies containing withheld history. This does not require deleting canonical history or altering accepted ADR text.

**Workspace preparation.** A trusted preparation operation exports the assigned committed source baseline and its necessary build/test inputs into an isolated task workspace. It includes applicable governing instructions, current specifications, relevant unchanged ADRs, the current brief and relevant future-consumer constraints. It excludes obsolete designs, completed assignments, superseded instructions, archives and the canonical `.git` directory. If local Git is required, use a fresh task repository containing only the selected snapshot; do not use alternates, shared object stores or a remote granting historical access. The workspace's source-baseline identity is supplied separately by the preparation operation. Any selection metadata is a derived task view, not a replacement catalog or authority source.

**Actual boundary.** Use a host-enforced restricted execution environment in which the worker cannot access the canonical store or widen its permissions. A directory name, gitignore, sparse checkout, prompt rule or hook is not sufficient. Filesystem mounts, symlinks, child processes, shell sessions, network credentials, Git remotes, MCP connectors and other-task-reading tools must respect the same boundary. The coordinator and reviewer also start with current context; historical access is a deliberate brokered operation, not an unrestricted history tool handed to every agent. The deployment design must name a supported host/sandbox configuration and demonstrate these properties before activation. The present unrestricted local task does not provide this isolation, and this proposal does not claim otherwise.

**Deliberate historical access.** The task names the historical question and required artifact. A controlled retrieval operation returns only the needed record or passage with its identity, lifecycle, applicability and provenance. The coordinator resolves relevance and authorization where judgment is needed. Do not expose arbitrary paths, bulk history searches or credentials through that operation. An ordinary compatibility lookup need not create a new owner-approval ritual when already within the task's scope; the important boundary is deliberate, scoped access rather than accidental ingestion. Explicit forensic audits can have separately assigned broader access.

**Changes return to the canonical repository.** The delivery owner exports its scoped candidate against the prepared baseline. The independent reviewer receives that candidate, original assignment and direct evidence in a separate isolated workspace. A trusted integration operation applies the reviewed candidate to the designated canonical integration checkout, rejecting path escapes, protected-file changes, out-of-scope files and an incompatible baseline. This operation must expose bounded actions, not an arbitrary shell or repository-history reader. Necessary canonical checks run there, including the full documentation checker: the reduced worker snapshot cannot stand in for checking the complete canonical catalog and links. Corrections return to the same delivery owner and reviewer. The authorized commit or publication endpoint uses that integration boundary; no worker receives unrestricted historical access merely to run Git.

**Roles remain unchanged.** The coordinator plus the fresh delivery owner and fresh reviewer remain three tasks. Integration is a controlled operation with one designated owner, normally the delivery owner, not a fourth default peer. Restricting how it executes does not transfer product implementation to the coordinator. Source/test tooling compatibility, including macOS builds and runtime review, must be demonstrated in the selected environment or through explicitly constrained check operations.

**Adoption implications.** Existing worktree instructions must be explicitly amended for this execution profile: writers use isolated snapshots or fresh task-only repositories rather than linked worktrees exposing historical objects. Preserve the accepted ADR records; place the new operating decision in the authorized current contract. Extend the shared-execution design and plugin with preparation, deliberate retrieval and candidate integration contracts, while leaving Release Radar's project database and catalog acceptance model intact. Existing product delivery cannot silently switch to this profile before its supported environment and recovery procedure are ready.

**Acceptance.** Demonstrate that ordinary source edits, required tests, independent review and canonical integration succeed. Demonstrate that recursive searches cannot return excluded historical content, and attempts through absolute paths, symlinks, Git objects/remotes, connectors, subprocesses and other-task history cannot bypass the boundary. Demonstrate a deliberate historical lookup, resume, cancellation and failed-integration recovery without granting broad access. Confirm canonical history and accepted ADRs remain preserved. If the current host cannot support this, the result is a specific host prerequisite and the full isolation outcome remains incomplete; a prompt or hook-only fallback does not pass.

### 2. Assignment and authorization

The coordinator derives one assignment from explicit owner direction and current accepted sources. The existing brief records the outcome, exclusions, applicable decisions, permitted endpoints, ownership, checks and review requirements. Prompt generation renders those decisions consistently rather than inventing or renegotiating them. Semantic interpretation still needs judgment; deterministic rendering does not approve that interpretation.

For executable checks, distinguish the human-readable brief from authorization supplied by the host. A run needs a binding to its actual task identity, role, repository, permitted actions and owner-authorized endpoint. The executing agent must not be able to grant itself additional permissions by editing its brief or supplying an approval-shaped string. Reuse supported host identity and permission facilities. If they cannot provide this binding, that is a named missing prerequisite for enforced task-specific authorization, not a detail to hide in a prompt validator. The proposal does not invent an app-owned approval service to fill the gap.

### 3. Dispatch and role separation

The coordinator remains a separate task from both delivery and review. A dispatch adapter using supported task APIs validates the assignment, creates the fresh delivery task from its committed baseline, and creates the fresh independent review task when a reviewable candidate is available. It reads back actual task identities and settings and rejects reuse outside the permitted correction scope. It does not fork the implementer's conversation into the reviewer.

For this to be enforcement, alternate task-creation tools must be constrained at the host boundary. Otherwise the adapter is only a reliable preferred route. The same distinction applies to preventing an orchestrator from implementing or spawning prohibited subagents: the task's verified role must determine tool/write capabilities. A role written in the prompt is not that capability boundary. No new delivery database is required; existing host task state and the existing ledger retain their separate responsibilities. The isolated workspace and bounded integration design above replaces unrestricted linked-worktree access for the proposed execution profile.

### 4. Where hooks and rules fit

Hooks are interception points around covered operations. Deterministic policy code can use those points to check the actual operation against the current document selection, protected paths, verified assignment and existing permissions before allowing it. For example, a supported structured document read can reject an obsolete brief during ordinary execution; a supported patch can reject an accepted ADR edit; a covered task-creation call can be checked against the permitted role and fresh-task assignment. Each example requires tested route coverage and the necessary trustworthy inputs.

Rules add suitable static command restrictions where a prohibition is actually invariant. A blanket ban on all pushes is inappropriate when some tasks have permission to push. Publication and other task-dependent permissions belong at a boundary that knows the actual authorization. Shell wrappers and continuing command sessions cannot be treated as solved by matching one command prefix.

The September 7 [I9 findings](../task-briefs/2026-09-07-parallel-discovery/rules-hooks-discovery.md) rejected three concrete proposals: context-blind publication bans, Stop continuation without reliable task/exit state, and broad PostToolUse access without demonstrated data minimization and executable trust. The later research does not resolve those missing inputs or invalidate that rejection. It supports replacing the proposed design: state-aware action checks and controlled context selection, with hooks used where they provide verified interception.

Consequently, automatic Stop continuation and broad command-output collection are not part of the initial target deployment. Existing direct checks and coordinator follow-through handle completion. Either feature needs its own demonstrated state/privacy prerequisites before inclusion; the complete workflow does not depend on them. This supersedes the earlier suggestion to treat all three hook types as an immediately useful pilot package. It preserves the earlier no-go for that package while proposing a different enforcement design.

### 5. Verification, completion and maintenance

The delivery owner produces the working candidate and direct evidence. The independent reviewer examines that candidate against the original outcome. The coordinator checks the agreed endpoint, records the concise result in the existing ledger, and archives completed bounded tasks. Tests, reviews, owner acceptance and authorization remain distinct facts. No hook infers quality or approval from a successful tool exit.

On task replacement or resume, regenerate the applicable assignment/context from current sources and re-establish the host's actual identity and permission state. Do not treat a previous conversation's paraphrase as authority. Later documentation changes update current specifications, lifecycle and active references together; obsolete material leaves default selection at closeout. Versioned control changes rerun the affected boundary checks before rollout. This is how the fix continues working after the initial cleanup.

## Relationship to the existing integrated workflow

These are proposed changes on adoption, not claims that the referenced artifacts have already been amended.

| Existing provision | Long-term disposition | Exact integration |
| --- | --- | --- |
| [Shared Execution Integration v1](../../design/shared-execution-integration-v1-design.md), local authority and minimum-context clauses | Retain the authority model; extend its implementation | Existing catalog and current sources feed deterministic selection; preserve consumer ownership and a concise assignment. |
| V1 on-demand skill and thin consumer adoption | Retain | The skill explains and invokes the workflow. It does not independently enforce permissions. Each consumer adopts an exact reviewed change. |
| V1 direct tools, documentation diagnosis and honest result reporting | Retain | Existing checker and tests remain evidence sources; neither diagnosis nor a passing check accepts a catalog or completes a task. |
| V1 exclusion of hooks, task scheduling and runtime enforcement | Amend through a separately versioned extension if adopted | Add the specified host-side selection, dispatch and action boundary. Do not imply these capabilities exist in installed V1. Preserve the exclusion of an app execution engine and second task database. |
| September 7 I9 no-go | Retain for its rejected designs; replace only a conclusion contradicted by new direct proof | Test the proposed state-aware controls and host inputs. Do not reinstall the rejected blanket bans, broad output collector or state-blind Stop reminder. |
| Full-product plan's earlier rules/PreToolUse, PostToolUse and Stop pilot table | Supersede as the proposed implementation package | Prioritize current-context selection, role-aware dispatch and pre-action checks. Leave automatic continuation and broad collection excluded unless their specific prerequisites are later met. |
| Existing orchestrator, separate delivery owner and independent reviewer | Retain; constrain actual execution access | Coordinator plus two fresh peer tasks; verified identity and settings, disjoint ownership, fresh reviewer context. |
| Linked writer worktrees with full repository/history access | Amend for the isolated execution profile | Prepared source snapshots or fresh task-only repositories; canonical history stays outside worker access; reviewed candidates return through bounded integration operations. |
| Operative-authority outcome 1 | Retain as completed baseline | Propagate its distinctions into current specifications and entry points without editing accepted ADRs or reopening completed review. |
| Remaining specification and shared-execution adoption outcomes | Integrate the complete end state | Specification work owns the whole stale-document correction; adoption connects it to the reviewed host controls and actual consumer configuration. |

The principal unresolved architectural dependency is a supported isolated execution host plus trustworthy identity, authorization and bounded preparation/integration operations that mediate the routes covered by the required isolation design. If not, present the owner with the concrete restricted-host option required for the full guarantee. Do not silently narrow the promised outcome to a prompt check or call the holistic fix complete after a partial pilot. Documentation correction can still be delivered while that enforcement dependency remains explicitly unresolved.

## Delivery A: current specifications and routine reading paths

This is the documentation portion of the existing next specification work. Integrate it with existing outcome 2; do not launch competing documentation cleanup.

1. Inventory the full relevant documentation estate and operative entry points using the existing catalog and indexes, including stale design documents, specifications, plans, briefs and runbooks. For each ambiguous document, identify its current use: live assignment, current specification, reusable runbook, proposal, decision record, or history. Resolve mixed documents at the level of the affected requirement, not merely the whole file's age.
2. Move continuing requirements from completed assignments into their owning mutable specifications where necessary. Preserve provenance links and distinguish retained requirements from obsolete process. Leave accepted ADRs untouched; place partial-acceptance and supersession explanations in current guidance beside the link agents encounter.
3. Close or archive stale assignment material using supported lifecycle transitions. Preserve stable artifact IDs and retained contents. Update active references, catalog metadata and generated indexes in the same candidate. Do not relocate app-managed evidence through direct filesystem edits.
4. Make existing entry pages give a short current-work path: owner assignment, applicable AGENTS.md, current progress, the assigned brief when required, then relevant current specifications and architecture constraints. Keep the complete generated inventory available as an inventory. Do not require every agent to ingest its contents.
5. Make historical retrieval explicit. Routine context selection excludes obsolete designs, plans, instructions and completed, superseded or archived assignments. A named historical, compatibility or provenance question can include a specific record, with its lifecycle and authority qualification attached. Useful active runbooks remain eligible when relevant. Catalog lifecycle alone must not erase an enduring requirement.
6. Reconcile current ledger entries that still describe closed tasks as active, based on actual task results. Retain useful closed detail in the existing archive. The coordinator owns this ledger edit; the delivery owner does not concurrently write it.

Completion evidence: the native documentation checker passes; active links and authority qualifications resolve; accepted ADRs are unchanged; representative ordinary tasks reach the correct current sources without historical assignments being supplied by default; a deliberate historical query can still recover the retained record and its status. No governing requirement disappears during the classification and reference changes.

Navigation changes reduce exposure but cannot stop an unrestricted shell from reading an archive. Delivery B must establish whether default selection can be enforced on the chosen execution route. Until then, describe this result as corrected documentation and improved default retrieval, not enforced isolation.

## Delivery B: establish and implement the execution boundary

The full-product plan currently records I9 as no-go and Run Guard as conditional. This proposed work explicitly reopens the I9 assessment for the current host only when the owner authorizes it. It does not silently overturn that decision or authorize I7's application execution engine.

Start by checking installed capabilities against the current official documentation. Use disposable fixtures, without owner data or external mutations. Inspect and test candidate controls before changing active agent configuration. Read-only host feasibility can proceed alongside Delivery A; policy-dependent implementation uses A's reviewed result.

| Property | Proposed mechanism | Required evidence and limit |
| --- | --- | --- |
| Current context supplied to a task | Select documents from existing catalog metadata and the assigned scope before constructing the task's reading set. Use existing retrieval facilities first; add only a small adapter if needed. | Capture actual supplied paths/content. Normal execution excludes historical assignments. Explicit historical retrieval preserves qualifications. Shell/MCP bypasses must be assessed separately. |
| Accepted ADR preservation | Block writes on supported paths; use the ordinary candidate diff check as a second check before delivery. | Attempt writes through every available claimed route. A diff failure detects a change; it does not prove writes were prevented. Hard protection requires a real write-permission boundary if hook coverage is incomplete. |
| Assignment structure | Validate coordinator role, exactly two fresh peer assignments per bounded outcome, independent reviewer context, writer baseline, ownership, model/effort and endpoint at dispatch. | Read back actual task IDs and exposed settings. A prompt describing roles is insufficient. Do not create tasks merely to test production dispatch without authorization. |
| Scope and permission | Compare a requested action with owner-authorized scope and endpoint. Obtain authorization from owner input or trusted host state, not text asserted by the executing agent. | Test absent, mismatched and fabricated references. If supported APIs cannot bind authorization to an owner event, report that limitation; keep consequential actions behind an existing owner-controlled boundary. |
| Completion | Use existing check results and coordinator follow-through. Automatic Stop continuation remains excluded without the reliable task/exit state required by I9. | Explicit STOP, questions, approval waits, interruption and real blockers remain terminal when appropriate. No automatic commits, publication or unbounded continuation. |

The route assessment includes shell commands and wrappers, apply_patch, MCP/task tools, nested code-mode calls, already-running command sessions, configuration trust/reload behavior and relevant alternate task-creation routes. Test normal allowed work as well as rejection cases. Hook errors and unsupported response fields must not silently count as successful blocking.

Prefer a narrow command/hook implementation using supported interfaces. Package it as a plugin only if packaging materially improves installation and repeatability. A prompt generator can produce consistent assignments, but is not the enforcement boundary. Do not introduce a second task database, a general workflow engine, transcript scraping, or an approval registry maintained by the same agent whose actions it supposedly authorizes.

Completion evidence: a concise list of installed-host controls that prevent actions, controls that only detect/remind, uncovered routes, and direct tests. Unsupported controls receive a specific no-go result. If full mediation is unavailable, the honest options are a narrower restricted execution route or retaining owner mediation for those actions; installation must not be described as universal enforcement.

## Delivery C: integrate and validate the working workflow

Integrate the reviewed documentation and proven controls with existing outcome 3, the shared-execution adoption work. Reuse its accepted contracts and checks. Do not activate guidance versions, consumers, hooks or application catalog acceptance merely because the source package exists.

Before rollout, specify the actual host, configuration files, command routes and repository covered, together with the supported means to disable or revert the new configuration. Protect unrelated user settings. Adopt only controls demonstrated by Delivery B; do not make ordinary delivery depend on a failed optional control.

Run a bounded pilot against the completed workflow:

- An ordinary assignment with an old conflicting brief present: the initial context uses the current assignment and specifications, and dispatch follows the required roles.
- A task involving a partially accepted ADR: the agent receives the qualification with the decision reference and preserves the ADR.
- An explicit historical question: the retained document is reachable and cannot silently become current authorization.
- A protected write or unauthorized endpoint attempt: the claimed control blocks it on every route covered by that claim.
- A legitimate allowed operation, owner STOP, approval wait and genuine blocker: the system permits or stops correctly without a continuation loop.

Use a few varied task formulations, including one not used while implementing the controls. For representative authorized work, record actual selected sources, dispatch/result, missed requirements, required corrections, owner interventions, false blocks and elapsed time when available. Use existing results and concise delivery evidence. Do not build a benchmark service or require statistical proof before correcting stale documentation.

The independent reviewer assesses the candidate and these observed behaviors. A clean catalog, a valid prompt, or a successful hook invocation alone does not establish success. Expand testing only for a concrete failed case or unresolved boundary.

Completion means the intended reading path works, retained history remains usable, covered mechanical violations are prevented, legitimate work and STOP are respected, and residual limits are explicitly documented. App-managed catalog acceptance or consumer activation is a separately authorized operation; repository checks do not stand in for application readback.

## Task ownership, sequencing and delivery endpoints

For each authorized bounded delivery above, the receiving task is explicitly the **coordinator**. It creates **exactly two fresh peer tasks**: one delivery owner and one independent reviewer. The reviewer receives the original outcome, constraints, candidate and direct evidence in fresh context, without forking the implementer's conversation. Dispatch does not imply completion; the coordinator monitors setup, results, required corrections and the agreed endpoint.

The standing chief architect provides bounded consultation for authority, cross-component contracts or recovery when needed. This does not add a third default delivery peer. No additional role matrix or review-of-review is introduced.

| Assignment | Starting model / effort | Ownership and endpoint |
| --- | --- | --- |
| Coordinator | Astra / medium | Scope, dependency release, actual task settings, one ledger writer, endpoint follow-through and completed-task archival. |
| A delivery | Sol / high | Documentation interpretation and cross-file authority corrections; scoped candidate, native checks and authorized local commit. Initial transition work uses its explicitly assigned existing environment; target-profile work uses the isolated workspace. |
| A review | Astra / high | Independent assessment of authority preservation, current requirements and actual reading paths. |
| B and C delivery | Sol / high | Host controls and isolated-workspace integration, with an explicitly assigned transition environment and exclusive configuration ownership during authorized activation. |
| B and C review | Astra / high | One independent review covering relevant authorization, bypass, recovery and workflow behavior. |

These are proposed dispatch settings, chosen for ambiguity and authority consequences. The coordinator sets and reads back actual supported model/effort settings. The ceiling is Astra/high; Ultra is excluded. An unavailable profile is reported, not silently replaced.

A writer's committed baseline must contain the approved scope and prerequisite changes. Resolve the actual revision at dispatch; do not reuse this planning document's dated baseline automatically. Serialize catalog/index integration and active configuration writes. The delivery owner integrates its candidate; the coordinator alone integrates ledger changes. Required corrections stay with the same assigned outcome and reviewer. Optional improvements do not block completion.

Before each dispatch, the coordinator prepares the concise brief from the owner's actual request and current accepted sources, including exclusions, material risks, relevant architecture, checks, file ownership and exact endpoint. Resolve only genuinely missing decisions with the owner. Approval of this plan must not be misreported as authorization for a push, merge, installation or owner-state mutation. No need to repeatedly ask for actions already explicitly authorized.

The sequence is A, then B's policy-dependent implementation, then C. B's read-only capability assessment may overlap A with disjoint ownership. A cannot be held hostage by I9 feasibility. Outcome 1 stays closed; outcomes 2 and 3 remain unopened until their execution is explicitly authorized. Existing product STOPs and paused work remain in effect.

## Disposition of this planning deliverable

This is a proposed, supporting plan for owner review, not an approved brief or active instruction set. Persist it in the existing plans collection with no mutable-document checksum. It does not change the full-product plan's decision states, the progress ledger, accepted ADRs or active configuration. No implementation tasks are dispatched by its creation.

Future completion records belong in existing progress and evidence locations. No competing roadmap or ledger is created. Repository publication and application synchronization remain distinct endpoints. The immediate deliverable is this plan; execution and its required independent candidate review follow the applicable authorization for each bounded outcome.
