# Phase 6E workspace Search and Help evidence

Date: 2026-09-10

## Delivered behavior

Release Radar now has workspace-level Search over authorized Projects, Delivery
Goals, persisted Execution Goals, tickets including retired records, current
decision references and all supported History sources. Query text, exact project-
registration scope, record domains and deterministic sort are explicit. A domain
read failure is reported as an omission and the projection is not called complete.
Searching itself performs no delivery mutation, file read or provider request.

Working Search state and named queries persist every supported filter in the
existing app-owned SQLite store. Unsupported future payloads remain visible and
deletable without guessed or dropped filters. Full backup includes saved queries,
tracking reset preserves them and restore rotates their authority; an old query
must be deliberately rescoped and resaved before execution.

Typed result navigation preserves exact registration and destination identity.
Back and Forward restore query, filters, sort, selection, viewport and keyboard/
accessibility focus. Opening a ticket in a nonactive phase changes only the viewed
phase. Shared searchable Help covers the nine selected workflows and exposes real
accessible navigation actions.

## Direct verification

All builds and tests used `ReleaseRadar.xcodeproj`, scheme `ReleaseRadar`, a
sanitized environment, unsigned arm64 serial execution and the retained offline
SourcePackages cache pinned to RekonDesignSystem revision
`6d1fb9d341850ee1d13ba9391fada072534eb684`.

- `results-green-07.xcresult` passed five initial cases: the Help catalog, all six
  Search domains and five History sources without query mutation, complete saved-
  query relaunch and unsupported-payload preservation, authority rotation, and
  incomplete-projection reporting. Its retired-ticket fixture failure was
  superseded by the focused pass below.
- `results-green-10.xcresult` passed the retired-ticket and deterministic collision-
  sorting case 1/1 after the synthetic retirement row was made consistent with the
  existing phase/lane, audit and disposition constraints.
- `results-green-11.xcresult` passed all three changed recovery cases and the
  primary-route accessibility labels 4/4. Its two failures isolated a new-ticket
  fixture lane and a missing Help child-accessibility container; both were bounded
  corrections superseded by GREEN12.
- `results-green-12.xcresult` passed Search → exact nonactive-phase ticket → Back/
  Forward restoration and automated native Search/Help rendering 2/2. The native
  case verified the Search, Help, filter, detail and supported/unsupported saved-
  query accessibility identities at 1,500- and 760-point widths, captured four
  attachments and confirmed that active phase did not change.
- `results-review-red-02.xcresult` then failed all ten added review-regression
  cases with 36 expected assertions. Those failures reproduced the review's
  required gaps: unsupported working-state preservation, explicit post-restore
  scope choice, byte-exact authority, optional decision metadata, exact audit and
  decision-link matching, destination-filter restoration, stale in-flight Search
  invalidation and shared Help guidance.
- `results-review-green-01.xcresult` passed those ten correction cases 10/10 with
  no failures. `results-review-green-02.xcresult` passed eight affected existing
  Search, navigation and recovery integration cases 8/8 with no failures.
- Delta review then identified one remaining recovery-clearing interleaving.
  `results-review-recovery-red-03.xcresult` failed the focused case 1/1 with the
  expected two assertions when an old pending Search republished its definition
  and projection after recovery cleared ephemeral state. Generation invalidation
  now occurs before recovery can suspend or transition stores and again whenever
  ephemeral Search state is cleared. `results-review-recovery-green-04.xcresult`
  passed that same case 1/1 with no failures.

The three recovery checks directly confirmed that full backup contains saved
queries, tracking reset retains them and restore preserves their bytes while
rejecting the pre-restore authority. The Search query case compared audit row
counts before and after the read. The navigation case compared the persisted
active phase before opening a result, after opening and after Forward restoration.

## Native visual and accessibility evidence

`results-native-build-01.xcresult` records the successful fresh build-for-testing.
The copied format-2 runfile resolved its test root, host, bundle, dependent-product
and profiling paths to that fresh unsigned build. Its only added target environment
was the unique session `phase6e-search-writer-20260910-01`.

`results-native-live-01.xcresult` then passed the isolated Search/Help journey 1/1
in 181.754 seconds. External CUA attached only after the ready marker identified
PID 63526, the exact fresh product executable and the tokenized window. It used
the keyboard to run the `VD2-08` ticket query and save **Native verified query**
(ID `8A0FE377-5C49-4282-AF45-DC19F63F3712`), opened the exact result, and verified
Back restored the query, ticket domain, Title sort, exact result and accessibility
focus while Forward restored the selected ticket. The active phase remained
**Post-MVP refinement**. It then returned through Back, opened contextual Help,
keyboard-filtered for saved-query guidance and used the recovery action to return
to Search.

The same journey narrowed the real window and scrolled Search to expose its Open
exact record action, then scrolled compact Help to its saved-query recovery and
navigation actions. Supported and disabled newer-version named-query controls,
filters and selected detail were visible. The automated rendering captures also
covered the recoverable newer-version working-query warning; the root-controlled
live fixture did not show that warning in its initial state, so the live inspection
does not claim it. CUA was stopped before the exact completion token was written,
and no UI call occurred after host exit. Host assertions confirmed active-phase
preservation and no dashboard failure.

Correction-native verification used a second fresh unsigned build. The first
automated attempt, `results-review-native-01.xcresult`, compiled and exercised the
real Reset, all-authorized and exact-project accessibility actions successfully,
but remained red because assigning an AX text-field value did not publish the
SwiftUI Help binding. That synthetic input approach was removed. The fresh
`results-review-native-build-02.xcresult` build-for-testing succeeded, and its
copied format-2 runfile resolved every product, host, bundle and profiling path to
that build while adding only the unique live-session token.

The root-controlled LIVE02 journey then used real keyboard input in the exact
tokenized PID and fresh product to filter Help for `source provenance retained
observations`, `delivery evidence applicability` and `newer version reset working
search`. Each query exposed the expected guidance and its real **Open History**,
**Open Goals** or **Open Search** action. CUA stopped before exact-token completion
and the host exited afterward. `results-review-native-live-02.xcresult` is retained
honestly as red because four pre-pause assertions incorrectly expected off-viewport
unfiltered Help cards in the 760-point accessibility tree; the live query evidence
itself is terminal. Those four assertions were removed, and
`results-review-native-green-03.xcresult` passed the final focused native fixture
1/1 with no failures, including disabled-before-recovery controls, explicit Reset
without replacing payload-version-99 bytes, both exact-scope choices and enabled
controls after valid recovery. Its unsupported-reset attachment is a coherent
post-reset UI capture. The exact-rescope attachment contains the verified native
filter strip but leaves the rest of the frame blank, so it is retained only as a
diagnostic attachment and is not presented as complete visual-screen evidence.

The canonical images are unchanged copies of the inspected passing attachments:

- [wide Search](2026-09-10-phase6e-search-wide.png)
- [compact Search](2026-09-10-phase6e-search-compact.png)
- [shared Help](2026-09-10-phase6e-help.png)

They preserve the approved dark Rekon hierarchy and History/Goals list/detail
language. Compact Search stacks detail beneath the exact selected row without
horizontal clipping, and compact Help keeps cards and real actions readable in
the vertical scroll. No approved mockup was replaced.

## Boundaries and retained outputs

No owner application store, owner repository content, credentials, provider,
notification, network, installation, catalog acceptance, push, pull request or
merge was used. Build products, result bundles, logs, exported automated
attachments, the copied xctestrun, native fixture stores and marker files remain
temporary diagnostics under
`/private/tmp/release-radar-phase6e-writer-01a08dee`. They are not controlling
artifacts. No temporary output was deleted.

The initial independent review identified eight Required correction groups; the
implementation and direct evidence above address all eight. Delta-review
disposition and the final local correction commit will be recorded after review.
