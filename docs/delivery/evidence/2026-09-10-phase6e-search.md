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

Except for the two explicitly identified native diagnostics below, builds and
tests used `ReleaseRadar.xcodeproj`, scheme `ReleaseRadar`, a clean allowlisted
environment, unsigned arm64 serial execution and the retained offline
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

## CodeRabbit correction candidate

The correction candidate prevents superseded or failed Search navigation from
publishing delivery-goal filters, viewed phases or ticket selection, and defers
cross-project ticket clearing until the destination navigation commits. Search
now presents a shared project label containing lifecycle and the full stable
registration ID in scope choices, recovery choices, result rows and selected
detail. Fresh schema 26 rejects zero-byte Search payload blobs and requires a
non-null saved-query ID while preserving nonempty opaque future-version bytes.
The pending-Search regression test now waits for the observable loading state
with a bounded clock instead of assuming one scheduler yield.

Focused test-first evidence retained under the temporary diagnostic root is:

- `results-coderabbit-red-01.xcresult` established the delivery-goal and phase-
  ticket stale-publication failures; its plan case was stopped after a faulty
  fixture failed to release its gate. `results-coderabbit-red-04.xcresult`
  subsequently established the plan-ticket stale-publication failure 1/1.
- `results-coderabbit-red-03.xcresult` established the three intended fresh-
  schema constraint failures; fixture cleanup was then limited to deleting the
  invalid rows between assertions. `results-coderabbit-green-01.xcresult`
  passed the deterministic loading-state case, delivery-goal case and schema
  case, while its two ticket cases exposed premature selected-ticket clearing.
- After moving that clearing to the successful commit boundary,
  `results-coderabbit-green-02.xcresult` passed all three superseded-navigation
  regressions plus the existing late-project-navigation regression 4/4.
  `git diff --check` also passes for the candidate.
- After independent review exposed the same-destination variant and the live
  journey exposed row-selection invalidation, root-controlled
  `results-coderabbit-final-green-01.xcresult` passed the three corrected
  same-destination regressions, the existing late-navigation regression and the
  exact Search selection/same-value-text regression 5/5 with no failures or skips.

The pre-existing `results-review-native-01.xcresult` path caused the first
requested correction-native command to stop before test execution, so it is not
new correction evidence. The fresh `results-coderabbit-native-01.xcresult` and
`results-coderabbit-native-02.xcresult` each passed both recovery-button native
identifier/text checks for `same-name-registration-a` and
`same-name-registration-b`, then failed before capture at the fixture's later
Search-projection unwrap. The cause of those two diagnostic failures was not
established; a launch-invalidation hypothesis did not survive the second run.
`results-coderabbit-native-03.xcresult` tried direct Search-view hosting but
failed before Search because its native accessibility subtree did not expose an
off-viewport recovery child. None of those three runs produced the requested
compact screenshot, and none is claimed as a passing whole fixture.
The NATIVE02 and NATIVE03 commands mistakenly inherited the process environment
while removing selected credential and session variable names instead of using
the authorized `env -i` allowlist. They remain failure diagnostics only and are
not accepted sanitized verification. No secret values were inspected. The
earlier correction RED/GREEN runs and NATIVE01 used the established clean
allowlist.

The bounded native replacement reused the established tokenized live journey in
the actual 760-point app shell. It captured
`phase6e-search-same-name-recovery-compact` before the pause and
`phase6e-search-same-name-compact` after the verified journey.

The first clean build-for-testing attempt,
`results-coderabbit-native-live-build-01.xcresult`, failed at compilation after
an overbroad test-only `let` cleanup changed an older fixture's intentionally
mutable native-window binding. That declaration was restored without production
changes. The root-controlled replacement
`results-coderabbit-native-live-build-02.xcresult` then completed the exact clean
allowlisted, unsigned, offline arm64 build-for-testing of candidate `08e04f5`
successfully. The copied
format-2 runfile `phase6e-coderabbit-native-live-01.xctestrun` points only to that
fresh product, resolves its test-root, host, bundle, dependent-product and
profiling paths, and adds only native-session token
`phase6e-coderabbit-same-name-01`. Root retains execution ownership.

The root-controlled live journey on `08e04f5` visually confirmed that both
same-name recovery actions, both result rows and both scope-menu choices displayed
their full unique registration IDs readably at the 760-point compact width. The
scope menu was inspected through its native accessibility items, but no menu-open
screenshot was captured. Selecting either exact result row reproducibly cleared
both rows before detail could be inspected. A same-value text-field write during
the focus transition is the current source-path hypothesis, not a proven runtime
cause; the model does unconditionally treat such a write as a new query. The
follow-up candidate makes same-value Search text updates idempotent and adds a
focused projection/selection preservation assertion.

Independent review of `08e04f5` also found that a route-only post-navigation guard
could not distinguish a newer navigation to the same phase board or project plan.
The follow-up candidate records the exact expected request generation and accepts
post-navigation Search mutations only when that same request committed. The three
focused regressions now supersede the older Search action with the same destination
and preserve the newer filter, viewed phase and selected ticket.

The root-controlled corrected LIVE02 journey used the exact clean allowlist and
the copied current-product runfile for candidate `97b90d2`. After the ready marker
identified PID 82472 and the exact tokenized window, CUA confirmed both stale-
scope recovery labels, chose all authorized projects and ran the existing project-
only query. Both full wrapped result labels remained visible after selecting the
first and then the second exact native row; selected detail updated respectively
to `same-name-registration-a` and `same-name-registration-b` and was complete and
readable after normal scrolling. The Scope menu exposed both exact full IDs through
its actual native menu items. That menu result is AX-only because no menu-open
screenshot was captured; its label uses the same reviewed `projectLabel` source as
the other three presentation sites. The final screenshot visibly retained the two
distinct wrapped row labels and the second registration's detail at compact width.

CUA was stopped before the exact completion token was written. The host then
asserted the two current registration identities and a selected result;
`results-coderabbit-native-live-02.xcresult` passed 1/1 with no failures or skips,
and PID 82472 was absent after exit. The result bundle contains both named compact
attachments. No UI call occurred after host exit.

## Boundaries and retained outputs

No owner application store or repository content was intentionally accessed or
mutated, and no credential was requested, retrieved or inspected. Because the
two identified `env -u` diagnostics inherited an environment outside the
authorized allowlist, incidental service or credential effects from those two
failed launches are unestablished rather than claimed absent. No provider or
notification mutation, installation, catalog acceptance, push, pull request or
merge was performed. Build products, result bundles, logs, exported automated
attachments, the copied xctestrun, native fixture stores and marker files remain
temporary diagnostics under
`/private/tmp/release-radar-phase6e-writer-01a08dee`. They are not controlling
artifacts. No temporary output was deleted.

For the pre-CodeRabbit Phase 6E outcome, independent Astra High reviewer
`01a08e2f-2be2-78d1-8bc0-ec72f17bc17d` approved the corrected source on September
11. All eight findings from that review were resolved. Its final source was
`d1445dc033fca9056782c493ebd04184d58fbc67`, following correction
`8056ae7e4063f3171d0410f87453c0b4adc9cad1` and initial candidate
`e7c92a25b61ce444b57b60a3a9e73159494b9398`. The independent Astra High reviewer
then final-approved CodeRabbit correction source
`97b90d2795b47b243ac580d0361ebb973972a307` after reading the 5/5 final direct
result, the 1/1 corrected live result and both compact attachments; no Required
finding remains. Four-site project-label acceptance is closed using the shared
label source, native recovery/result/detail observations and actual menu AX.
Publication, installation and owner application-state acceptance are separate.
