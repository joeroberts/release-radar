# Phase 6: outcomes, tasks and history

Status: planning candidate under independent architecture/sequencing review.
Source baseline: `e5372d170d9202d207922fe51f38bcf0827a2967` (merged Phase 5 and shared V1 plus ledger closeout).

## Outcome and authority

The owner authorized Phase 6 planning followed directly by bounded local
implementation. The [whole-product plan](2026-09-06-full-product-architecture-and-delivery-plan.md)
defines inclusion; this plan resolves the delivery sequence without dropping any
selected outcome. [Progress](../progress.md) owns live authorization and assignments.
Installation and owner testing wait until September 11 or later and separate
authorization. Source completion does not claim installed acceptance.

The complete outcome is workspace Delivery Goals, the distinct Execution goal
browser (P14), generic task adoption (P10/[issue #1](https://github.com/joeroberts/release-radar/issues/1)),
revision-bound evidence (P17), workspace search/saved views (P19), event-time
History with coherent attention, and RM10 Help for these and existing journeys.
P6 cardinality/suggestions are not selected. Live observation, companion, Run
Guard, hooks, Phase 7 portability, consumer adoption and distribution are excluded.

## Current contracts and proposed implementation choices

- D5: aggregate existing phase-owned Delivery Goals; retain explicit readiness,
  acceptance, supersession and carried obligations. Use a workspace Goals
  destination with explicitly separate Delivery and Execution views. No
  cross-phase outcome or 1:N execution-link migration. Execution defaults to All
  Projects / All goals, including completed/unlinked persisted observations;
  link identity, observation provenance and freshness remain independent.
- D6: extend `AppRoute`, `NavigationHistoryEntry` and the existing AppModel
  navigation boundary. Stable project/registration/entity identity and explicit
  filter domain travel together. Browsing never changes active phase. Back and
  Forward preserve filter, selected detail, scroll and focus. Unsupported or
  unavailable saved targets recover without silently broadening scope.
- D7: event identity, occurrence time, recording/observation time and provenance
  differ. Capture facts at the event transaction, preserve source history, and
  leave unknown legacy fields unknown. Today's lane/phase is not an old event's
  lane/phase. History reads never create attention, replay notifications or grant
  acceptance. Claimed thread attribution does not verify independence.
- D13: identify repository separately from source revision; record tested
  revision, dirty-worktree applicability, result scope/source/time, documentation
  revision and build/installation identity where known. Expected evidence,
  observations and acceptance remain separate. A prior revision's passing result
  cannot silently satisfy a newer commit, merge or installed binary. Preserve
  manual/local evidence and unknown legacy provenance. No implicit network access,
  test execution, Git mutation, publication or acceptance from viewing/refreshing.

The current source has reusable phase-goal/task policies, scoped query dispatcher,
revision receipts, all-phase board and retained removal/recovery. It lacks
workspace goal routes, complete typed task inventory and saved query restoration.
`ProjectActivityProjection` currently decorates old events with current ticket
lane/phase; `ActivityView` lacks the selected History filtering/detail journey.

## Bounded sequence

| Slice | Complete deliverable | Dependencies and direct evidence |
| --- | --- | --- |
| 6A History and attention | Immutable event facts/provenance, filterable History with retained identity navigation, honest empty/error/unknown states, existing attention/deduplication safeguards and contextual History Help | Existing audit, retention and navigation. Exercise later lane/phase changes, replay, import/restore/removal and native wide/compact Back/Forward. |
| 6B Workspace Goals | Separate Delivery/Execution views; criteria/coverage/readiness and acceptance context; completed/unassigned/unlinked historical discovery; all-phase associated work and exact goal-to-board restoration; Goals Help | 6A event identity and current phase-owned policies. Test colliding IDs across scopes, unknown observations, no active-context mutation and native filtered navigation. |
| 6C Revision-bound delivery evidence | Ticket evidence panel and typed recording/readback for repository/commit/PR/check/document/build/installed facts with applicability and missing/stale/unavailable distinctions; evidence Help | Stable ticket and 6A event identity. Test wrong repository, older revision, dirty worktree, unknown installation, unavailable source, exact replay and retained recovery. |
| 6D Generic task adoption | Complete scoped typed inventory; owner-visible atomic/non-atomic/already-planned/blocked reconciliation; exact approved catalogs, resumable existing receipts, explicit evidence-backed past completion and readback; product guidance v3 and adoption Help | Current task policies, 6A history and 6C evidence applicability. Test unavailable/partial reads, stale revisions/registration, Accepted/Completed guards, creation pending at revision 1, replay and recovery. |
| 6E Workspace search, saved views and complete Help | Authorized known-record search across projects, both goal domains, tickets, decision references and History; persistent filter/scope/sort and typed restoration; contextual and searchable Help for selected setup/recovery/planning/acceptance journeys | Consumes 6A–D record identities. Test cross-project collisions, withdrawn/archived/removed targets, incomplete/error versus zero matches, unsupported filters and relaunch. |

Each slice is independently reviewable and ends in a scoped local commit with
affected documentation and direct evidence. This sequence is not permission to
build generic infrastructure ahead of its first consumer. A bounded query belongs
with the feature needing it. Later briefs refine implementation details within
this complete scope; material changes to scope/sequencing return to the parent.

The chief's read-only assessment found no remaining owner choice blocking this
scope. It suggested goals first as a low-migration initial outcome. History first
is selected here to establish truthful capture before later new mutation flows;
combining the two goal views makes their domain distinction reviewable together.
Evidence precedes adoption so its past-completion journey consumes real revision
applicability. These are sequencing choices, not additional product requirements.
Saved queries persist in the existing full-backup boundary, with versioned query
preferences and fresh authorization on restoration; session Back/Forward remains
session-only. They are excluded from a single-project portable package. Future
RM5/RM6 must represent the new records or reject unsupported content, but no
portability implementation is added to this phase.

## Guidance and compatibility

Issue #1 authorizes minimum changes to PRODUCT-owned guidance templates and
packaged skill source, plus focused audited-handoff tests. ADR-006 reserves guidance
v3 for this outcome. It does not authorize rewriting governing AGENTS, installed
skills/config, consumer instructions or guardrails. Package changes preserve
shared-V1 immutable version/digest inventory compatibility; unknown pairs remain
unsupported. No deployment or application adoption occurs here.

## Verification and delivery

Use test-first behavior changes and repository-native focused XCTest checks.
One independent risk-appropriate peer covers each material candidate, including
its architecture/authority/recovery and UX/QA risks where present. Required
findings receive bounded corrections and affected rechecks; successful review
and checks are terminal. No review matrices or review-of-review.

All native verification uses an established inert synthetic XCTest host, sanitized
`env -i`, unique retained output and explicit serialized host reservation by the
orchestrator. Inspect startup configuration before launch and verify the host PID
before external AX/CUA attaches. Never launch a plain DerivedData or installed
owner application. No owner SQLite, credentials or services. Runtime screenshots,
keyboard/AX and relevant widths compare against repository mockups; limitations
remain explicit. Synthetic restoration verifies new persistence without owner data.

Writers own their complete source slice, affected design/ADR text and canonical
evidence; the orchestrator alone integrates catalog/index/progress. New durable
artifacts use catalog identities and repository paths, mutable records have no
checksums. Run documentation validation. Application catalog acceptance/readback
remain separately unauthorized and cannot be claimed from a local check.

Orchestration is Astra Medium; history/adoption/evidence writers use Sol High for
cross-component provenance/recovery risk, ordinary UI/search work starts Terra
Medium unless its bounded brief identifies higher ambiguity. Ceiling Astra High;
never Ultra. Fresh task worktrees start from the exact committed controlling
baseline, one product writer at a time. Archive completed bounded peers after
source/evidence preservation and process handback.

Push/PR is not yet authorized for Phase 6; each merge and installation requires
separate approval. Present the first reviewed slice's concrete publication
endpoint to the parent before accumulating the full phase unpublished. No cleanup,
notifications, external scans, consumer changes or owner-state mutations.
