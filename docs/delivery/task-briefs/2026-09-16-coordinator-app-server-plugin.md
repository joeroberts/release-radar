# Coordinator worker plugin

## Objective and authorization

Deliver a reusable local MCP plugin that starts and follows Codex workers through
App Server with explicit checkout, permission profile, model, effort and bounded
assignment. Owner approved this outcome and a one-time exception for Main to
implement directly on September 16. Desktop visibility and handoff are not
requirements. Native hook verification is complete and remains unchanged.

## Assignment and scope

Main owns implementation and documentation in branch
`codex/coordinator-app-server-plugin`, worktree
`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar-coordinator-plugin`,
from `8cd8cd8a1052b59a6e0344ab7c204840072e063f`. Preserve all primary-checkout dirt.
Source lives under `plugins/coordinator-workers/`; no changes to the RR app,
accepted ADRs, existing hooks, global configuration, installed plugins or history.
Main's current model is used under the direct-implementation exception; no Ultra.
A fresh independent reviewer will cover protocol, security and behavior together.

## Contract and dependencies

Use the documented App Server stdio interface through a local MCP server. Python
standard-library transport is sufficient; no new service, database or UI.
The minimal tool interface is start, status/results, follow-up, interrupt, and
respond to a pending approval. Tools operate only on this adapter's workers.
Configuration selects the executable, authorized checkouts and named profiles;
callers cannot supply arbitrary commands, environment or App Server config.
Validate returned settings before releasing a worker turn. Explicit errors and
unknown outcomes must survive transport failure; never automatically repeat an
uncertain launch or turn request. Keep task state in App Server; bounded in-memory
connection state belongs to the adapter. Reconnection must not claim a stopped
worker without evidence.

Worker-only configuration disables launcher and alternative retrieval tools and
subagent creation, while the selected filesystem profile denies excluded history
and shared Git metadata. Preserve historical files and catalog identities in place.
Main retains deliberate historical retrieval outside ordinary worker tools.
Profile names alone are not proof of effective rules. A returned profile identity
is provenance, not a complete filesystem/tool attestation. Active input documents
may themselves contain historical passages; path restrictions do not redact them.
Owner-maintained launcher configuration must be outside worker write authority.
Do not accept caller-supplied role assertions as authentication.

Approvals retain request/thread/turn identity and explicit allowed decisions.
Do not auto-approve, widen the worker profile or turn denial into a retry elsewhere.
Unsupported approval types must remain visible and safely unresolved or declined.

Sources: [App Server](https://learn.chatgpt.com/docs/app-server),
[plugins](https://learn.chatgpt.com/docs/build-plugins),
[MCP](https://learn.chatgpt.com/docs/extend/mcp),
[permissions](https://learn.chatgpt.com/docs/permissions#scope-and-enforcement),
[configuration](https://learn.chatgpt.com/docs/config-file/config-reference).
Named permission selection is experimental. Installed schema inspected:
`codex-cli 0.154.0-alpha.6.2`. Trust documented contracts; test the adapter and only
investigate concrete integration mismatches. No tests of Main's task metadata.

## Material risks and acceptance

Prevent unauthorized checkout/profile selection, config override, cross-worker
control, approval replay, recursion and history access through alternative tools.
Handle asynchronous results, interruption, process loss and partial startup honestly.
Use configured checkout roots for portability; no user-specific paths in runtime
code. Source remains standalone from RR's sandboxed app and plugin lifecycle helper;
ADR-001/ADR-002 app and helper boundaries are unchanged. No data migration.

Acceptance requires working plugin packaging, explicit fresh-worker startup,
status/results and follow-up, interruption, approval handling, enforced bounded
inputs and worker-tool settings, focused tests and one independent review. A
bounded live integration check must establish adapter behavior against the installed
App Server; do not substitute mocks for that check. Any inability to verify full
history exclusion remains an explicit incomplete requirement.

## Verification and endpoint

Test first at the adapter layer using Python unittest and controlled transport
fixtures for races/failures. Validate plugin manifest with Plugin Creator's existing
validator. Run repository documentation check and git diff check. Use a single
independent reviewer for the implementation, not a reviewer of evidence reports.
Persist concise results here and in the existing progress ledger; maintain catalog
and indexes. No new review artifact or evidence framework is needed.

Endpoint: local implementation, verification and review. No push, PR, merge,
installation, marketplace registration, app-state changes or global permission
changes. Preserve existing installers, historical material and the completed pilot.

## Local delivery result

The local plugin candidate is implemented and independently reviewed. Twenty-five
focused unit tests pass. Plugin Creator manifest validation, repository documentation
checks and diff checks pass against the working tree. No commit, push, PR,
installation, marketplace registration, global configuration or app-state mutation
occurred. Catalog changes are branch-local and pending acceptance only if this
candidate is later adopted into the managed repository.

Direct live checks established exact RO/RW checkout/profile/model/effort startup,
synthetic archive-read and RO-write denial, restricted-worker writes with network
disabled, result delivery, follow-up, and Main deliberate synthetic-history retrieval.
Actual MCP stdio initialize/list/start/status/result/close passed. After review
corrections, worker 01a0abaf-3113-71a0-931f-22e35b375dd8 completed through that MCP
entrypoint with rr-project-restricted and wrote LAUNCHER_PROTECTION_OK; the owner-side
readback matched exactly. Both installed RR profiles validate against this real
worktree and its resolved common Git directory. A linked-worktree test rejects
missing common-Git denies and narrower object-store grants. Real historical contents
and catalog identities were preserved; no probe read those contents.

The owner extended the one-time Main exception to independent reviewer launch.
Reviewer 01a0abab-2c2b-7930-bb0f-1a8d5c6bd098 ran with verified exact checkout,
rr-project-ro, Sol/high and read-only/network-disabled settings. It found three
Required defects: worker-writable executable, grants reopening launcher/configuration
writes outside checkout roots, and replay after uncertain approval response. The
candidate now rejects overlapping grants and replaceable ancestors, protects the
actual executable/interpreter/source/policy, and consumes an approval identity before
sending while preserving unknown delivery. Regression tests cover these defects.
The same reviewer rechecked corrections and returned PASS with no remaining Required
findings. The earlier inaccessible RO04 reviewer was archived after its blocked
result was preserved; it supplied no implementation verdict.

Compatibility and limits: named permission selection is experimental. Concrete
profiles without inheritance, globs or additional profile roots are supported;
unsupported or overlapping write grants fail before a worker turn. The adapter does
not repair profiles. OpenAI's configuration source establishes agents.enabled=false
with multi_agent_v2=false as the explicit multi-agent disablement; live worker
self-report agreed, but is not a complete tool-inventory attestation. Unknown
transport outcomes are not replayed; this version retains App Server identities but
does not reattach after adapter loss. Active input documents can contain historical
passages; filesystem exclusions do not redact their contents. These limits are
reported in the plugin skill and do not authorize deployment or weaken isolation.

Temporary files retained pending cleanup authorization:
.build/coordinator-integration/ (fixtures and mcp-policy.json) and plugin scripts
__pycache__/ bytecode. Git ignores these files. Synthetic App Server records remain
preserved. Durable implementation and documentation are in this repository worktree.
