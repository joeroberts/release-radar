# P6 Manage Project — Task03: verify access and recovery

## Outcome and scope

Complete the existing `rr-p6-manage-project-task-03`: verify authorization,
archived and removed project access, partial failures and accessible navigation
with independent UI and recovery review. Preserve the approved task definition.
Task01 and Task02 are implemented and reviewed; this assignment covers remaining
acceptance properties, not a repeat of their successful checks.

Use [Task02](2026-09-20-manage-project-task02.md) for relocated-control boundaries,
the [selected design](../../design/phase6-workspace-toolbar-proposal.md) and its
wide/compact references, and [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md)
for retained authority boundaries. The [ledger](../progress.md) controls current
authorization and evidence. No public contract, persistence, migration or recovery
policy change is intended. Navigation consumes this management surface next;
Archive/Remove relocation and Guided Setup remain separate tasks.

## Dependencies and assignment

Start from canonical `codex/manage-project-context-recovery`, including integrated
Task02 `5ab10618` and ledger `3e97b67f`, plus the committed preparation of this brief.
RR must return a baseline containing that integration and this brief before work
starts. Use shared-execution/1 and the exact canonical project identity; the app
assigns an isolated checkout. Confirm effective worker model/effort from supported
worker status, not merely this document.

Assign an independent QA/recovery worker that authored neither Task01 nor Task02.
Defined-scenario coverage starts at Terra/medium; named exploratory recovery
ambiguity may escalate to Sol/high, with Astra/high as the ceiling. No Ultra.
One independent worker can cover UI, authorization and recovery risks; do not
create separate reviewers for the same properties or review this review.
Main owns ledger/catalog metadata. Existing Build Agent owns compilation, tests
and Git. The worker owns bounded test selection, direct scenario assessment and
findings. No product edits during this verification assignment; return any
Required defect to Main for a bounded correction and affected recheck.

## Direct verification and material risks

First map existing direct evidence to the remaining properties. Run only checks
that resolve a named uncovered property; source inspection alone does not prove
an authorization or recovery boundary.

- Exact registration/root identity and stale selection: a late response or stale
  preview must not update or mutate another selected project.
- Archived/removed access: management availability and callbacks must retain the
  existing lifecycle policy. Exercise disposable fixtures, not owner projects.
- Partial failures: independently loaded sections remain usable; retry targets
  the failed section and retains exact identity and actionable errors.
- Accessible navigation: moved controls are reachable in sensible keyboard order;
  error focus/announcement and root/worktree recovery remain within the presented
  management surface. Retain the completed wide/compact visual and focus evidence
  unless a newly identified defect affects those properties.
- Evidence and folder controls retain existing freshness, authorized-root and
  preview/confirmation protections at their changed integration boundaries.

Use repository-native focused tests and existing synthetic rendering fixtures.
Build supplies test results and images; inspect actual rendered images against
the selected references where a remaining visual property needs evidence. Do not
repeat the held-app inspection route that exposed live owner rows, create a new
capture harness, weaken tests or change permissions/configuration. Preserve all
existing source, branches, worktrees, installers and temporary artifacts.

## Acceptance and endpoint

Return concise passed/failed/unavailable results for the properties above with
exact source basis and useful result paths. Classify findings Required, Optional
or Out of scope. Only correctness, authority, recovery or explicit acceptance
defects block; optional polish does not. Missing direct evidence remains explicit.

Completion means remaining Manage Project acceptance properties have direct
evidence and independent assessment, or a precisely identified Required defect
has been corrected and checked. Main records results in the existing ledger;
Build commits scoped test/documentation changes if any. Do not produce a separate
review-report artifact solely to restate messages or test results.

No owner data mutation, RR task completion/acceptance, permission change, branch
push, PR, merge or installation is authorized by this verification assignment.
The completed app batch retains the owner's separate standing local-release
authorization; Main releases that endpoint only after Manage Project is complete.

## September 21 owner-approved tracked reconciliation

Owner approved evidence and three task completions in Main task
`01a0c4b2-46c6-7e81-ae75-da56109621d1`. Existing plan is already planned,
revision 1. Keep all three active task IDs, labels, titles, sort orders and
lifecycles unchanged; no additions, definition revisions or supersessions.
Complete Task01, Task02 and Task03 only after current evidence readback shows
each exact scope applicable, available and passed. Keep ticket in progress and
owner acceptance notAccepted. All other tickets and phase state are unchanged.
The current restart handoff supplies attributed prior delivery claims; recording
these claims does not rerun checks or turn them into fresh local observations.
The observation timestamps identify this handoff reconciliation readback.

Execute the following exact requests in order, recording each returned revision
and audit ID below. Stop on baseline change; replay only the same request after
an uncertain outcome. Evidence revisions and task-plan revisions are separate.

```json
[
  {
    "tool": "release_radar_record_delivery_evidence_target",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "target": {
        "catalogDigest": "08fdebfafb30cf7f7e5a6aada7112550d7b7b8acc85dce274d0a401bf06f6f7f",
        "catalogVersion": 1,
        "projectID": "project-fffdc0e0b15b9b86",
        "repositoryID": "e7475429-ef51-4368-ad9e-61d9073d5a4f",
        "rootID": "project-fffdc0e0b15b9b86-root-0"
      },
      "expectedEvidenceRevision": 0,
      "revision": {
        "checkoutState": "clean",
        "commitSHA": "c9a4a16a9ad9440cefc1a609314640c4027ed588"
      },
      "expectations": [
        {
          "category": "check",
          "scope": "rr-p6-manage-project-task-01"
        },
        {
          "category": "check",
          "scope": "rr-p6-manage-project-task-02"
        },
        {
          "category": "check",
          "scope": "rr-p6-manage-project-task-03"
        },
        {
          "category": "check",
          "scope": "rr-p6-manage-project-local-release-0.1.34"
        }
      ],
      "reason": "Owner-approved September 21 Manage Project reconciliation: record released source target and exact task/release scopes; no owner acceptance.",
      "requestID": "3ea70ef5-3294-404a-b0eb-770c67e35547"
    },
    "deliveryEvidenceRevision": 1,
    "auditEventID": "7F2D1862-5DFC-45EC-A001-7CED29BF89D3"
  },
  {
    "tool": "release_radar_append_delivery_evidence_observation",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "target": {
        "catalogDigest": "08fdebfafb30cf7f7e5a6aada7112550d7b7b8acc85dce274d0a401bf06f6f7f",
        "catalogVersion": 1,
        "projectID": "project-fffdc0e0b15b9b86",
        "repositoryID": "e7475429-ef51-4368-ad9e-61d9073d5a4f",
        "rootID": "project-fffdc0e0b15b9b86-root-0"
      },
      "expectedEvidenceRevision": 1,
      "reason": "Owner approved recording the current handoff as attributed evidence; no new test run or inferred acceptance.",
      "observation": {
        "id": "7d88a89b-07f1-4e70-81a6-f66e5f534eac",
        "targetVersion": 1,
        "fact": {
          "category": "check",
          "scope": "rr-p6-manage-project-task-01"
        },
        "source": {
          "kind": "recordedClaim",
          "label": "docs/delivery/progress.md \u2014 September 21 Manage Project delivered 0.1.34; restart handoff. Task01 implementation and direct checks complete: exact project identity, independent loading and local retry. Attributed prior delivery result, not a fresh execution."
        },
        "sourceAvailability": "available",
        "outcome": "passed",
        "observedAt": "2026-09-21T16:04:14Z",
        "recordedAt": "2026-09-21T16:04:14Z"
      },
      "requestID": "5ed0f6b2-1135-46ba-991d-6239c24cc39e"
    },
    "deliveryEvidenceRevision": 2,
    "auditEventID": "70E3FD12-EAE4-4BD1-BB85-38F7D5C30614"
  },
  {
    "tool": "release_radar_append_delivery_evidence_observation",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "target": {
        "catalogDigest": "08fdebfafb30cf7f7e5a6aada7112550d7b7b8acc85dce274d0a401bf06f6f7f",
        "catalogVersion": 1,
        "projectID": "project-fffdc0e0b15b9b86",
        "repositoryID": "e7475429-ef51-4368-ad9e-61d9073d5a4f",
        "rootID": "project-fffdc0e0b15b9b86-root-0"
      },
      "expectedEvidenceRevision": 2,
      "reason": "Owner approved recording the current handoff as attributed evidence; no new test run or inferred acceptance.",
      "observation": {
        "id": "3b9ca5fa-a8eb-4ac7-896b-fa901d524b9a",
        "targetVersion": 1,
        "fact": {
          "category": "check",
          "scope": "rr-p6-manage-project-task-02"
        },
        "source": {
          "kind": "recordedClaim",
          "label": "docs/delivery/progress.md \u2014 September 21 Manage Project delivered 0.1.34; restart handoff. Task02 implementation and direct checks complete: relocated documentation, execution, repository access and evidence controls. Attributed prior delivery result, not a fresh execution."
        },
        "sourceAvailability": "available",
        "outcome": "passed",
        "observedAt": "2026-09-21T16:04:14Z",
        "recordedAt": "2026-09-21T16:04:14Z"
      },
      "requestID": "3fa74d39-778d-4bd7-ba64-1616398b8844"
    },
    "deliveryEvidenceRevision": 3,
    "auditEventID": "9A78CC01-8F99-4AC9-B7A4-0B82E1449845"
  },
  {
    "tool": "release_radar_append_delivery_evidence_observation",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "target": {
        "catalogDigest": "08fdebfafb30cf7f7e5a6aada7112550d7b7b8acc85dce274d0a401bf06f6f7f",
        "catalogVersion": 1,
        "projectID": "project-fffdc0e0b15b9b86",
        "repositoryID": "e7475429-ef51-4368-ad9e-61d9073d5a4f",
        "rootID": "project-fffdc0e0b15b9b86-root-0"
      },
      "expectedEvidenceRevision": 3,
      "reason": "Owner approved recording the current handoff as attributed evidence; no new test run or inferred acceptance.",
      "observation": {
        "id": "14fbde0c-671d-4ce1-8933-66e149b0d15d",
        "targetVersion": 1,
        "fact": {
          "category": "check",
          "scope": "rr-p6-manage-project-task-03"
        },
        "source": {
          "kind": "recordedClaim",
          "label": "docs/delivery/progress.md \u2014 September 21 Manage Project delivered 0.1.34; restart handoff. Task03 independent verification complete: authorization, archived/removed access, partial failures, accessibility and recovery. Attributed prior delivery result, not a fresh execution."
        },
        "sourceAvailability": "available",
        "outcome": "passed",
        "observedAt": "2026-09-21T16:04:14Z",
        "recordedAt": "2026-09-21T16:04:14Z"
      },
      "requestID": "f41e9e7b-13d4-49a2-b8f4-12dfc9a4fee5"
    },
    "deliveryEvidenceRevision": 4,
    "auditEventID": "E60B93E0-A336-400D-8DF1-0EDFA59DA57C"
  },
  {
    "tool": "release_radar_append_delivery_evidence_observation",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "target": {
        "catalogDigest": "08fdebfafb30cf7f7e5a6aada7112550d7b7b8acc85dce274d0a401bf06f6f7f",
        "catalogVersion": 1,
        "projectID": "project-fffdc0e0b15b9b86",
        "repositoryID": "e7475429-ef51-4368-ad9e-61d9073d5a4f",
        "rootID": "project-fffdc0e0b15b9b86-root-0"
      },
      "expectedEvidenceRevision": 4,
      "reason": "Owner approved recording the current handoff as attributed evidence; no new test run or inferred acceptance.",
      "observation": {
        "id": "071b74d7-17fa-46c3-bcd4-99444a42d2a8",
        "targetVersion": 1,
        "fact": {
          "category": "check",
          "scope": "rr-p6-manage-project-local-release-0.1.34"
        },
        "source": {
          "kind": "recordedClaim",
          "label": "docs/delivery/progress.md \u2014 September 21 Manage Project delivered 0.1.34; restart handoff. 0.1.34 delivery complete: DMG, signatures, installed identity and executable equality; annotated tag remote peeled commit matched. Attributed prior delivery result, not a fresh execution."
        },
        "sourceAvailability": "available",
        "outcome": "passed",
        "observedAt": "2026-09-21T16:04:14Z",
        "recordedAt": "2026-09-21T16:04:14Z"
      },
      "requestID": "151b78e8-99d0-4762-8411-bd34df68d09b"
    },
    "deliveryEvidenceRevision": 5,
    "auditEventID": "2A8BB31B-410C-4992-8DCF-6C1F86E10D0E"
  },
  {
    "tool": "release_radar_complete_ticket_task",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "expectedRevision": 1,
      "taskID": "rr-p6-manage-project-task-01",
      "reason": "Owner-approved September 21 reconciliation; complete exact existing task after applicable available successful scoped evidence readback. Preserve definitions and owner acceptance.",
      "requestID": "555ced0e-5d93-4b3b-9805-44dfbd22b1b5"
    },
    "ticketTaskPlanRevision": 2,
    "auditEventID": "C1B4E824-0863-499A-9E2A-EBBEE74144DE"
  },
  {
    "tool": "release_radar_complete_ticket_task",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "expectedRevision": 2,
      "taskID": "rr-p6-manage-project-task-02",
      "reason": "Owner-approved September 21 reconciliation; complete exact existing task after applicable available successful scoped evidence readback. Preserve definitions and owner acceptance.",
      "requestID": "29b12250-d195-46d6-909f-848ac72ea9b5"
    },
    "ticketTaskPlanRevision": 3,
    "auditEventID": "85F18E7F-B65C-4825-B2BC-7C0E26040325"
  },
  {
    "tool": "release_radar_complete_ticket_task",
    "disposition": "committed",
    "arguments": {
      "version": 1,
      "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
      "registrationID": "8edc840e-2847-4eeb-af68-282d5ed12b11",
      "registrationProjectID": "project-fffdc0e0b15b9b86",
      "requestGeneration": 1,
      "assertedThreadID": "01a0c4b2-46c6-7e81-ae75-da56109621d1",
      "ticketID": "rr-p6-manage-project",
      "expectedRevision": 3,
      "taskID": "rr-p6-manage-project-task-03",
      "reason": "Owner-approved September 21 reconciliation; complete exact existing task after applicable available successful scoped evidence readback. Preserve definitions and owner acceptance.",
      "requestID": "34313796-2834-4b4c-b271-c862832745f7"
    },
    "ticketTaskPlanRevision": 4,
    "auditEventID": "E599D4E9-26F3-4CD7-AB18-60E096C9F050"
  }
]
```
