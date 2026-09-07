# Discover supported live Codex observation

## Assignment brief — 2026-09-07

Status: authorized bounded discovery; findings pending. This artifact records a
proposal, not accepted architecture or implementation.

Establish whether a supported authenticated interface can observe the intended installed desktop instance, including stable task/goal identities, events, reconnect and freshness. Starting an unrelated app-server process does not prove attachment. Return a concrete supported approach or evidence-backed no-go, with dependencies and truthful unavailable behavior.

Use current official OpenAI documentation (OpenAI Docs skill) and bounded local capability inspection. No private-state or transcript scraper as a product integration. Separate verified capability from hypotheses. I1/RM7 feeds live agent status and observation; useful delivery and document browsing does not depend on it.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Retain all 40 capabilities and accepted versus proposed distinctions. RDS appearance
is unchanged. This discovery does not reopen completed lifecycle work or gate C4.

Model/effort: gpt-5.6-sol / high; ceiling: Astra High; Ultra prohibited. Assigned baseline is
`c4ddffb` plus the committed discovery briefs/catalog preparation on
`codex/recovery-orchestration`; the dispatch supplies its exact revision. Use a fresh
worktree and named `codex/discovery-live-observation` branch with upstream. Own only this
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

### Decision

**No-go for I1/RM7 live observation against the current installed desktop
instance.** Do not implement a Release Radar App Server client, local helper,
hook-based substitute or private-state reader from this discovery. Preserve the
existing `unavailable` observer result and downgrade any last-known observation
to `stale`, including its checked time and reason. This remains the truthful
degraded dependency outcome and does not gate C4 or ordinary delivery/document
browsing.

The public App Server protocol has materially improved since the earlier RR-05
assessment, but the missing property is still attachment to the intended running
desktop process. The current desktop process owns its App Server over parent
stdio; no documented, authenticated endpoint is exposed for a separately
sandboxed application. Starting another App Server or daemon would create a
different runtime and cannot establish live status for the desktop-owned task.

### Evidence and classification

#### Current official OpenAI documentation

- [Codex App Server](https://learn.chatgpt.com/docs/app-server) is the documented
  product-integration interface. It has stable and experimental method tiers,
  thread/list and thread/read snapshots, runtime thread status, thread/turn/item
  events, a Unix-socket transport and bearer authentication for explicitly
  configured WebSocket listeners. The page nevertheless instructs the client to
  **start** `codex app-server`; it does not document attaching to the already
  running desktop application's child process. It also labels the App Server
  command and WebSocket transport experimental and unsupported for production
  workloads.
- A client receives events only on its active App Server transport after it
  starts or resumes a thread. `thread/read` intentionally neither loads the
  thread nor subscribes to its events. `thread/status/changed` identifies a
  thread and status, but the documented notification has no event sequence,
  replay cursor or observation timestamp. The documentation does not define a
  reconnect/freshness protocol that can prove no events were missed.
- Thread identity is usable: App Server supplies stable `thread.id`, `turn.id`
  and a `thread.sessionId` for the live session-tree root. Goal identity is not:
  `thread/goal/get|set|clear` exposes one mutable goal value keyed only by
  `threadId`. Replacing the objective resets usage, while the documented goal
  has no immutable `goalId`, generation, revision or update timestamp. It cannot
  satisfy Release Radar's persistent `(project, ticket, thread, goal)` identity
  without inventing source identity.
- WebSocket bearer modes authenticate a listener explicitly started with the
  relevant flags. They do not authenticate access to the installed desktop
  instance, because that instance does not expose such a listener. The
  documented connection is also a broad read/write JSON-RPC surface containing
  archive, delete, steer and unsandboxed shell-command methods; no method-scoped
  read-only credential is documented.
- [The desktop app overview](https://learn.chatgpt.com/docs/app) confirms that
  the app presents projects and long-running work to its user. It does not
  publish an observer API for another local application.

#### Verified installed capability — 2026-09-07

- `/Applications/ChatGPT.app` reports version `26.901.41600` (build `7982`). Its
  bundled Codex executable reports `codex-cli 0.153.4`, matching the separately
  installed CLI checked in this task.
- Bounded process inspection found the desktop-owned child invoked as `codex
  ... app-server` with no `--listen` argument. The same installed binary's help
  states that the default is `stdio://`. Socket inspection of that exact child
  found only anonymous parent/child Unix sockets and no named Unix, TCP-listening
  or UDP endpoint. No alternate App Server process was started.
- The installed CLI now advertises `app-server daemon`, `app-server proxy` and
  `codex agents` for a separately managed shared daemon. The desktop child is not
  launched as that daemon and owns no control-socket listener, so those commands
  do not attach to its active in-memory threads.
- The task-local `codex_app.read_thread` capability successfully returned this
  desktop task's stable task and turn IDs, title, working directory, timestamps
  and active status. That proves the first-party app can observe its own task.
  Process inspection shows this capability is injected into the desktop child as
  a bundled MCP server using an app-owned ephemeral pipe. Neither OpenAI's public
  App Server documentation nor installed CLI help exposes that pipe or MCP server
  as an authenticated third-party integration contract. No transcript content
  from the probe is retained here.

#### Rejected hypotheses and unavailable proof

- **Separate App Server/shared daemon:** supported enough to build a client for
  tasks owned by that server, but it is not the installed desktop process.
  Stored-thread discovery from shared local files would at best return persisted
  history or `notLoaded` status from the second process, not authoritative live
  desktop runtime state.
- **Desktop private IPC or bundled `codex_app` bridge:** visibly exists, but its
  protocol, authentication, lifecycle, compatibility and sandbox contract are
  not public. Depending on it would be private-state integration, not supported
  observation.
- **Database/rollout files, Accessibility, Full Disk Access or screen scraping:**
  prohibited by ADR-001 and unnecessary to test. They cannot be fallbacks.
- **Rules/hooks or agent-authored status pushes:** are separate decisions and do
  not provide passive, complete, independently fresh observation of all desktop
  tasks. This discovery does not configure them.

### Acceptance matrix

| Required property | Result | Reason |
| --- | --- | --- |
| Attach to intended installed desktop process | **Fail** | Desktop App Server is parent-owned stdio; no supported attach endpoint is exposed. |
| Authenticate a separate sandboxed observer | **Fail** | Documented bearer auth applies to an explicitly started listener, not the desktop child; Unix/private IPC has no public observer contract. |
| Stable task/thread and turn identity | **Pass in protocol** | `thread.id`, `turn.id` and `sessionId` are documented and the app-local read probe returned them. This does not cure attachment. |
| Stable goal identity | **Fail** | Goal is mutable state keyed by `threadId`, with no immutable source `goalId` or revision. |
| Live events from the intended process | **Fail** | Streaming is scoped to the App Server connection that owns/resumes the thread; a second process does not observe the desktop child's in-memory stream. |
| Reconnect and freshness | **Fail** | No documented notification replay cursor/sequence/timestamp; snapshot reads do not establish a gap-free live stream. |
| Project/privacy scope and least privilege | **Fail** | The connection can enumerate/read broader Codex history and exposes mutation/execution methods; no read-only project-scoped capability is documented. |
| Sandbox-compatible recovery | **Unproven** | There is no supported endpoint to test. Private socket/file exceptions or broader entitlements are not acceptable substitutes. |

### Product behavior and future reopen condition

Keep the existing normalized observer seam so historical and unavailable
execution browsing remains useful. A refresh must report `unavailable` with the
specific unsupported-attachment reason and check time; an outage or old snapshot
must never appear live, infer acceptance or move a ticket lane. P14 can browse
historical/unavailable execution records, and I6 can publish delivery documents,
evidence and history without live agent status. This decision changes none of the
40 assessed capabilities or their accepted/proposed maturity, retained history,
portable-package contents, Mac delivery authority, repository document authority
or unchanged RDS appearance.

Reopen I1 only when current official OpenAI documentation and the installed
desktop product jointly provide all of the following:

1. an explicit supported way for another signed application to attach to the
   desktop-owned runtime, rather than start a parallel App Server;
2. authenticated, revocable, least-privilege read access scoped to selected
   projects/tasks, with no generic mutation or shell authority;
3. immutable provider/thread/goal identities, including distinct goal
   replacement generations;
4. a snapshot-plus-subscription or cursor/sequence contract that closes the
   reconnect race and lets Release Radar assign truthful observed/fresh/stale
   times under duplicate, delayed and reordered delivery; and
5. a proven macOS App Sandbox connection and recovery flow that stores any
   credential in the app-owned Keychain boundary and fails closed on version,
   authorization or endpoint mismatch.

Meeting those conditions would justify a separate owner-approved implementation
brief and focused compatibility/security proof. It would not itself authorize
implementation, entitlements, installation or application-state mutation.

### Verification and residual risk

Checks were read-only: official OpenAI documentation retrieval; installed and
bundled CLI version/help; exact desktop/App Server process arguments; named Unix
and network listener inspection; one current-task `codex_app.read_thread` probe;
and repository source/contract review. No App Server, daemon, hook, helper or
listener was started, so there is no process to stop. No temporary files were
created.

The main residual uncertainty is future product change: a later desktop release
may adopt the documented shared daemon/control socket or publish the current
first-party bridge. That possibility is a reopen trigger, not evidence for the
present build. Runtime-selected model and reasoning effort were not exposed to
this task; the requested `gpt-5.6-sol` / `high` assignment therefore could not be
independently confirmed. Ultra was not used.
