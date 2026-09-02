# RR-R10 Task 4B: Audited ticket-task commands

Status: Completed implementation and acceptance, 2026-09-02. Retained as
non-authoritative delivery history; current status and sequencing are in
[progress.md](../../progress.md).

## Objective and outcome

Expose the delivered Ticket Task policy through two bounded, audited,
idempotent commands and packaged MCP tools. Creation, definition revision,
supersession and completion return the revision committed by the existing
policy. Task completion never moves a ticket or Delivery Goal.

The owner authorized preparation of this brief and the post-MDCP plan refresh
on 2026-09-02. Implementation authorization is recorded separately in
[progress.md](../../progress.md). This brief does not authorize installation,
owner-data changes, catalog acceptance or shared macOS service changes.

## Scope and exclusions

Production paths:

- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`: additive command cases,
  optional `ticketTaskPlanRevision` result and task-policy error representation.
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`: validate, invoke
  the policy inside the existing transaction, scope the audit and persist the
  committed result for exact replay.
- `ReleaseRadarAgentTools/main.swift`: two strict schemas and translators.
- `ReleaseRadar/Shared/FailureStateView.swift`: compile-required exhaustive
  mapping for the additive errors. The coordinator confirmed this minimal
  supporting compatibility edit on 2026-09-02; it adds no UI workflow.

Test paths:

- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`: command behavior,
  receipt/result compatibility, failure and concurrency.
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`: packaged
  schemas/translators and controlled transport acceptance; update the existing
  tool-count assertion from 19 to 21.
- `ReleaseRadarTests/NotificationAcceptanceTests.swift`: no notification,
  review or lane side effects from task-only operations and rejected requests.
- `ReleaseRadarTests/DocumentationCallbackTests.swift`: replace the obsolete
  assertion that the task-plan tool is absent; retain all six MDCP tools and
  read-only inventory checks. This fourth test path is necessary compatibility
  maintenance, not a change to the MDCP contract.

Add `reviseTicketTaskPlan` and `completeTicketTask`, exposed as
`release_radar_revise_ticket_task_plan` and
`release_radar_complete_ticket_task`. Use the existing version-1 envelope,
request UUID, authorized project root, reason and asserted thread attribution.
The revision command carries ticket ID, optional expected revision, additions,
definition revisions and superseded task IDs. Completion carries ticket ID,
task ID and a required exact revision. Omitted operation arrays mean no action.
Additions use `TicketTaskDraft`; definition changes use
`TicketTaskDefinitionRevision`. Neither payload accepts completion or lifecycle
state. Core validates typed command bounds; MCP schemas/translators also
reject unknown fields and unsupported operation shapes. Supplied revisions
must be positive `Int64` values; sort order is a nonnegative `Int`. Reject
nonintegral, boolean, out-of-range and malformed numeric inputs.

Preserve all 19 current tools and their schemas, adding exactly two. Preserve
`AgentCommandResult.inventory`, old encoded results, documentation query
routing, ordinary canonical JSON receipts and MDCP digest receipts/replay.
Expose the named task-policy failure categories from the design through an
additive Codable command-error mapping; revision conflict includes the actual
current revision. Existing command errors, including Task 4A's Accepted path,
retain their behavior. Do not report expected task-policy rejection as a new
generic internal failure.

No schema/model/policy rewrite, new acceptance tool, import/UI changes,
Delivery Goal commands, feature flags, broker repair or test framework is in
scope. The two tools remain limited to isolated development/test use until
Tasks 5, 6 and 7 are accepted. Task 7A owns the later owner installation and
live bootstrap. Preserve the held Issue #2 artifacts and historical manifests.

## Dependencies

- [Remaining implementation plan](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md),
  [Ticket Tasks contract](../../../design/release-radar-ticket-tasks-design.md),
  [ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
  [ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md)
  and [ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md).
  Historical package-pending and schema-v10 handoff prose is not a new gate.
- Delivered Tasks 1A/1B/2A/2B/3/4A, including the immutable v11/v12 foundations,
  `TicketTaskPlanningPolicy` and every-path Accepted gate.
- Completed MDCP, with `MDCP-COMPAT-2` (`b365aff`) as the accepted application
  baseline: schema v13, app/plugin 0.1.6, guidance v2, catalog v1 and 19 tools.
- `TicketTaskPlanningPolicy.revisePlan(projectID:ticketID:expectedRevision:
  additions:definitionRevisions:supersededTaskIDs:connection:)` and
  `completeTask(projectID:ticketID:taskID:expectedRevision:connection:)` return
  a persisted `TicketTaskPlanRecord`. Both consume the caller's transaction;
  neither creates the dispatcher audit or request receipt.

## Material risks

- **Revision/receipt atomicity:** the dispatcher currently constructs ordinary
  command results before applying mutations. For these two commands, derive
  the returned revision from the policy result inside `DeliveryStore.transact`,
  then encode/persist that same result and `.ticketTaskPlan` audit atomically.
  Do not read a revision afterward or return a guessed R+1. A late failure
  rolls back every effect; exact replay returns the original committed result.
- **Authority and concurrency:** preserve root/project/ticket validation,
  non-spoofable origin and attribution. Never derive task state from Markdown,
  Git, tests or Codex goals. Competing acceptance and task mutations must use
  the existing store transaction and fail without partial state.
- **Compatibility:** retain Task 4A's Accepted-upsert rejection and exact
  task-revision gate. New task commands must not normalize MDCP receipts,
  consume current catalog state before an authorized MDCP replay, or turn
  read-only inventory into a mutation.
- **Test isolation:** XCTest's temporary store and suppressed normal startup
  do not isolate tests that explicitly start the fixed macOS bridge service.
  The whole transport class is unsafe in an ordinary live session. The named
  development selections below avoid that service. Required packaged broker
  acceptance uses an isolated macOS service/session environment; if only the
  owner's shared service is available, prepare the exact test/quiescence/
  restoration package and obtain separate authorization before running it.
  This gate cannot be satisfied by silently skipping transport acceptance.

## Test strategy

Use test-first development with existing XCTest fixtures. Add failing cases
for the new commands, then the smallest dispatcher/helper changes. Keep the
accepted policy and MDCP tests as dependencies rather than rewriting them.

Focused development invocation from the authorized development worktree:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/rr-r10-task4b -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests/testPackagedToolRespondsToInitializeWhileInputRemainsOpen \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests/testMalformedNumbersAndPresentNonStringOptionalsRejectBeforeTransportOrWrite \
  -only-testing:ReleaseRadarTests/DocumentationCallbackTests \
  -only-testing:ReleaseRadarTests/ManagedDocumentationOperationsTests/testInventoryBindAdoptReplayAndRelaunch \
  -only-testing:ReleaseRadarTests/ManagedDocumentationOperationsTests/testEveryDocumentationMutationReplaysAndRejectsRequestReuseAcrossRelaunch \
  -only-testing:ReleaseRadarTests/ManagedDocumentationOperationsTests/testEveryDocumentationMutationRollsBackAfterLateReceiptFailure \
  -only-testing:ReleaseRadarTests/ManagedDocumentationOperationsTests/testManagedEvidenceCannotRelocateAndReplayDoesNotConsumeLaterCatalog

xcodebuild build \
  -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/rr-r10-task4b
```

Add any new stdio-only transport selectors explicitly. Valid packaged command
translation, app-unavailable behavior and lost-reply recovery must also pass
through the controlled broker path described above. The existing
`testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`,
`testCallbackInvalidationAfterHandoffReturnsOutcomeUnknownAndReplayWritesOnce`
and `testAfterReplyWorkCannotDelayCommittedToolResult` are not ordinary-session
selections. Use their existing mechanisms for controlled acceptance, without
changing service identity, signing or shared registration as an implicit setup
step. No unfiltered full-scheme run is required for this slice.

The implemented stdio-only additions are
`testTicketTaskToolSchemasPreserveExistingToolsAndRequireBoundedRecords`,
`testMalformedTicketTaskInputsRejectBeforeTransport` and
`testTicketTaskInputBoundariesRejectBeforeTransport`.

The bounded controlled alternative is
`AgentBridgeTransportAcceptanceTests/testTicketTaskToolsUseRegisteredBrokerAndRecoverExactRequests`.
Independent Security/Privacy source review accepted this operation with no
required findings. Run only this selector from the prepared test build with
`test-without-building`, parallel testing disabled, and the native 90-second
maximum test execution allowance. It requires an already-enabled service and
no other app host before connecting, uses synthetic fixture storage, and
disconnects without unregistering. It covers both valid task tools, committed
receipts/revisions, exact replay, callback loss and unavailable-app refusal.

Execution requires separate approval for gracefully quitting and relaunching
the unchanged `/Applications/ReleaseRadar.app`, including ordinary startup
notification recovery/sending and eligible plugin lifecycle work. All Release
Radar callers, UI actions and service changes must be held, and originating
callers must resolve any pending or uncertain request before the pause. Keep
the installed broker registration, broker process, lifecycle helper and
existing MCP clients. Re-resolve their identities before execution.

After success, failure or interruption, wait for this run's test host and
helper processes to exit, confirm the broker still resolves to the unchanged
installed app, relaunch that exact app, and prove callback restoration using
the existing read-only evidence inventory at the saved bound repository root.
Only then release callers. A registration mismatch or failed restoration
requires escalation, not manual service repair. There is no owner installation,
live task/catalog mutation, direct database access, or owner-store byte-identity
claim in this operation. Test artifacts are retained under the existing
custody rules.

Exercise the accepted boundaries directly: 63/64/65 aggregate operations;
65,535/65,536/65,537 bytes in the sorted-key encoded `AgentCommand`; and
255/256/257 UTF-8 bytes for IDs/labels plus 4,095/4,096/4,097 for titles,
using ASCII and multibyte values. Schema/translator checks cover required and
optional fields, omitted arrays, pending-only additions and exact command
round trips. Verify old result JSON remains unchanged when the new revision
field is absent, including MDCP inventory results and durable replay results.

## Acceptance criteria

1. Nil-revision creation returns revision 1; existing-plan changes and each
   completion require the exact current revision and return the committed next
   revision. Additions are Active/Pending; IDs/labels and completed/superseded
   history retain all accepted policy invariants.
2. Wrong project/ticket/task, malformed or oversized input, duplicate/conflicting
   operation identities, stale revision, no-op, changed-body request reuse and
   out-of-order completion reject with useful typed errors and no effects.
   A revision conflict reports the actual current revision.
3. Each successful mutation has one committed `.ticketTaskPlan` audit and
   request receipt with the same result/revision. Exact creation, revision and
   completion replay returns that result; a late receipt/transaction failure
   leaves no task/plan/audit/receipt, notification, review or lane change.
4. Exercise all four accepted concurrency schedules using existing store test
   infrastructure: no-plan acceptance versus first creation; acceptance at R
   versus add/supersede at R; acceptance at R versus completion at R; and two
   revisions or completions at R. Assert the coherent winner and exact loser
   rollback, including no orphan rows or extra owner-attention effects.
5. The packaged helper exposes the original 19 tools plus the two new strict
   schemas. Controlled transport proves valid translation, committed results,
   app-unavailable refusal and outcome-unknown recovery by replaying the exact
   complete original request. Existing MDCP compatibility cases pass.
6. Task-only operations preserve ticket lanes, phase-plan state/revision,
   Delivery Goals, evidence and notifications. Every Accepted entry point and
   both Accepted-upsert rejection branches remain as delivered in Task 4A.
7. Focused checks, Debug build and the applicable independent reviews pass;
   the complete slice and concise delivery evidence receive a verified
   fast-forward push. Temporary test outputs retain the repository's existing
   custody/disposal rules. No owner install or live bootstrap occurs here.

## Risk-triggered reviews

Independent code or QA review covers implementation and direct verification.
Architecture review covers the additive public command/result/error contract
and transactional revision result. Security/Privacy review covers authorized
roots, attribution, durable replay, failure rollback and controlled transport
isolation. One independent reviewer may cover multiple relevant competencies;
the implementer cannot supply independent acceptance. No new UI or sequencing
decision calls for a separate UX/TPM gate. Successful reviews are terminal
unless they identify a required defect; do not review the review.
