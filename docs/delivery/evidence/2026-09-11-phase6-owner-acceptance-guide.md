# Release Radar 0.1.9 owner acceptance guide

Date: 2026-09-11

## Candidate identity and scope

This guide covers every merged product change from the start of Tuesday,
September 8, 2026 through the completed Phase 6 baseline:

- Delivered-product range: `cd16df1b0226aa8a08bd167364779103ebe86278..5e7b9b86e55cd8aed192fb116bbe0bcae9bea66a`
- Merged pull requests: #33 through #48
- Acceptance-correction source: `acc740113d1e7e056b5e7f1b2e3a0e3e21f24c27`
- DMG package artifact commit: `09caafe0108496297684089603aa04c0cfffe361`
- App version/build: `0.1.9 (1)`
- DMG: `dist/ReleaseRadar-0.1.9-acc7401.dmg`
- DMG SHA-256: `bfb3e769f7f5acea37aeca0573a8a53ad484795fcbe2f36c07010c8f6fe7b046`
- Main executable SHA-256: `52a4a1a8015fde064582c8768828d60907b641d09d827c15806919c2b283e428`
- CodeDirectory hash: `cf90e9252c9b56e1699041d098987b37dea340ce`
- Signature: Apple Development, team `2UA854NLX4`, Hardened Runtime enabled

The earlier `ReleaseRadar-0.1.7-fb2ff3b.dmg` and diagnostic
`ReleaseRadar-0.1.9-5e7b9b8.dmg` are not the acceptance candidate. The former
predates this guide; the latter contains the five focused failures described in
the previous revision of this guide.

The 0.1.9 DMG is an owner-only local build. Its bundle and nested code pass strict
signature verification, but it is not notarized and Gatekeeper does not assess it
as a generally distributable app. Phase 7 portable export/import is not in this
build. Phase 7 implementation remains paused.

## Automated verification status

The five focused failures in the diagnostic candidate are corrected in this
candidate:

- The exact five reported tests plus a direct byte-distinct key regression test
  pass 6 of 6. Canonically equivalent Delivery Goal IDs now remain distinct in
  Swift collection keys, finalization coverage, and successor transfer selection.
- The affected planning, successor, proposal, lifecycle, history, migration,
  recovery, and shared-execution suites pass 114 of 114 unsigned tests.
- The historical migration fixtures now unwind newer empty schema in dependency
  order and refuse to discard nonempty data. Production migration strictness is
  unchanged.
- The XCTest fixtures resolve their physical temporary root before exercising the
  no-follow reader. Product `O_NOFOLLOW` and symlink-ancestor rejection remain
  unchanged.
- Agent-bridge expectations now cover all 37 tools, current delivery inventory,
  complete delivery-goal obligations, and test-owned broker registration. An
  unsigned agent-bridge selection passed 11 of 13; its only two failures were the
  expected code-signing rejection when unsigned tests attempted to load a signed
  LaunchAgent.
- A signed test bundle builds successfully, but the corrected signed service tests
  have not yet run. They require explicit authorization to temporarily register
  and unregister the test LaunchAgent services. The prior diagnostic baseline's
  plugin lifecycle result was 14 of 14; that result is not attributed to this
  rebuilt candidate.

The exact correction commit received independent source review with no Required
or Optional findings. The rebuilt Release bundle and every nested executable pass
strict signature, Hardened Runtime, and exact-entitlement verification. The DMG
verifies, mounts read-only, and contains byte-identical executable and CodeResources
copies of the staged app.

Do not record this build as owner-accepted yet. The remaining automated acceptance
gap is the authorized signed service run, followed by the manual owner checks in
this guide. Phase 7 remains paused.

## Time budget

- Quick pass: 20–30 minutes
- Complete navigation and inspection pass: 45–60 minutes; Search interactions
  persist workspace UI preferences
- Disposable-project mutation pass: 60–90 minutes
- Optional global backup/restore checks: 20–30 minutes plus restore time

## Install and migration preparation

Installing 0.1.9 and launching it for the first time can migrate the application
store to schema 26. An older app must not be pointed at that migrated live store.

1. In the currently installed Release Radar, open **Settings** and choose
   **Create Backup…**. Save the `.release-radar-backup` package somewhere you
   control and confirm it exists before continuing.
2. Remember that this backup contains the supported local database, preferences,
   history, plugin receipts, and notification history. It does not contain
   credentials, repositories, portable project files, or device permission grants.
3. Quit Release Radar.
4. In Terminal, change to the repository checkout containing the package artifact
   commit above, then verify the DMG checksum from the checkout root:

   ```sh
   shasum -a 256 dist/ReleaseRadar-0.1.9-acc7401.dmg
   ```

   Expected digest: `bfb3e769f7f5acea37aeca0573a8a53ad484795fcbe2f36c07010c8f6fe7b046`.
5. Open the DMG and drag **ReleaseRadar.app** onto its **Applications** link.
   Approve Finder's Replace prompt if an older app is installed.
6. If macOS blocks the first open because this local build is not notarized,
   Control-click `/Applications/ReleaseRadar.app`, choose **Open**, review the
   identity, and choose **Open** again. Do not disable Gatekeeper system-wide or
   strip quarantine/signature metadata.
7. In Finder, select the installed app and choose **Get Info**. Confirm version
   `0.1.9` and build `1`. Optional Terminal verification:

   ```sh
   codesign --verify --deep --strict --verbose=2 /Applications/ReleaseRadar.app
   shasum -a 256 /Applications/ReleaseRadar.app/Contents/MacOS/ReleaseRadar
   ```

   The executable digest should match the value above.
8. Launch 0.1.9. Existing projects should load without a schema error. Do not
   reinstall 0.1.7 over the migrated live store. A rollback requires quitting
   0.1.9, reinstalling the earlier app, and restoring the pre-upgrade backup.

## Quick low-risk smoke pass

Use an existing project with representative data only after completing the backup
precautions above. These checks do not change delivery records or repository files,
but Search query, scope, filter, and sort interactions persist the workspace's
working Search definition as application preferences. Do not save or delete a
named query in this quick pass.

1. Confirm the sidebar contains **Projects**, **Search**, **Goals**,
   **Needs Review**, **Notifications**, **Settings**, and **Help**. Open a project
   and confirm its secondary destinations include **Overview**, **Project Plan**,
   **Phase Board**, **Dependencies**, and **History**.
2. Open **Project Plan**, then **Open all-phase board**. Choose a ticket and use
   **Back** and **Forward** in the title bar. Repeat with Command-[ and Command-].
   Expected: the exact route, viewed phase, filter, selection, scroll position,
   and focus return; the project's active phase does not change.
3. Open **History**, choose a source filter and an event, scroll, open its recorded
   ticket when available, then go Back. Expected: the filter, exact event, detail,
   viewport, and focus return. Legacy rows may honestly show unknown historical
   facts rather than current values.
4. Open **Goals**. Switch between **Delivery** and **Execution**, apply one filter,
   select a row, and open associated work where available. Expected: formal
   Delivery Goals and persisted Codex execution observations remain distinct;
   Back restores the Goals context.
5. Open **Search**, search for a known ticket ID, narrow the record types, change
   sort order, select a result, and choose **Open exact record**. Go Back and
   Forward. Expected: query, scope, domains, sort, selection, viewport, and focus
   restore without changing active phase or delivery state.
6. Open **Help** and search separately for `saved query`, `source provenance`,
   and `delivery evidence applicability`. Expected: relevant cards remain, and
   their **Open Search**, **Open History**, or **Open Goals** actions navigate to
   the real destinations.
7. On **Project Overview**, find **Shared execution** and choose
   **Refresh compatibility**. Expected: one honest read-only state such as
   Compatible with V1, Not declared, Pending catalog acceptance, Incompatible,
   or Unavailable, with direct results/recovery where applicable. There must be
   no adoption, install, or update action in this panel.
8. Resize the window to about 760 points wide and repeat a ticket detail, History,
   Goals, Search, and Help check. Expected: inspectors stack below their lists,
   controls remain reachable by scrolling, text wraps, and there is no horizontal
   clipping.

## Disposable-project mutation setup

Complete this setup before any state-changing step in the feature checklist below.
Do not use a production repository or important Release Radar project for those
mutation checks.

1. Create a new local Git repository with an initial commit and a few small Markdown
   files. Use a name such as `RR Owner Acceptance 2026-09-11`.
2. Add it through **Projects → Add Project…** and complete only the normal supported
   documentation handoff shown by the app. Keep all generated documentation inside
   that disposable repository.
3. After installing 0.1.9, update/install the bundled Release Radar Codex plugin
   through **Settings** only if the app says that action is needed.
4. In Codex, always name the exact disposable root and project. Ask it to use the
   installed Release Radar tools, show the current inventory and exact revisions,
   preview the intended mutations, and wait for your explicit approval.
5. Seed two phases, at least two Delivery Goals, one unplaced ticket, placed tickets
   in both phases, a cross-phase dependency, several task definitions, a cataloged
   requirement/decision reference, and evidence expectations. Keep one nonactive
   phase so navigation can be tested.
6. Capture the project/registration, phase, goal, ticket, proposal, reference,
   evidence-target, and task revision IDs that Codex reports. Use those exact IDs
   when evaluating the UI.

## Complete feature checklist

Inspection-only steps may use representative data, but every refresh, lifecycle,
proposal, evidence, task, saved-query, project, plugin, or other persistence-changing
step must use the disposable setup above after the backup precautions.

### Phase 3A — documentation freshness and folder recovery

1. On Project Overview, inspect documentation health and managed evidence.
2. Choose the existing refresh/recheck action. Expected: the prior success is
   withdrawn while checking, then one current observation is published.
3. If a test project has a deliberately stale folder bookmark, choose
   **Restore folder access** and select that exact saved folder. Cancel once first:
   cancellation must not change state. On the second attempt select the exact
   folder. Expected: access recovers without silently accepting a changed catalog
   or changing project/repository identity.

### Phase 3B — bounded evidence preview

1. Select a ticket or project evidence record with a small text or raster file.
2. Choose **Preview**, then **Refresh preview**. Expected: text/image content is
   shown with its locator and availability; truncated text is labelled.
3. Check an HTML or SVG evidence file if available. Expected: inert source text,
   never active web/SVG execution.
4. Check a missing, oversized, malformed, unauthorized, or symlinked fixture in
   the disposable project. Expected: a typed inaccessible/rejected state and an
   exact recovery route; no path substitution or content from outside an
   authorized project root.

### Phase 4 — coherent navigation and Ticket Details

1. View a nonactive phase, select a Delivery Goal filter and ticket, open
   **Dependencies**, then use Back. Expected: the nonactive viewed phase, goal
   filter, selected ticket, and focus return while active phase is unchanged.
2. In Dependencies, confirm cross-phase prerequisites and dependents show phase
   labels and the selected path remains readable.
3. Go Back, then navigate somewhere new. Expected: Forward becomes unavailable.
4. At compact width, select a ticket with many tasks and Tab through the task
   rows. Expected: rows are focusable and scroll into view without changing task
   completion.

### Phase 5A — recorded Project Plan and first placement

1. In a project containing unplaced work, open **Project Plan**. Confirm counts for
   recorded tickets, phases, and **Not placed**.
2. Select an unplaced ticket. Expected: its definition, tasks, dependencies,
   references, evidence, and audit identity remain visible, but it is absent from
   the five execution lanes and cannot execute or complete.
3. Open the all-phase board. Expected: exactly five lanes and one phase label per
   card; **No Delivery Goal** remains distinct from **No phase**.
4. Through an owner-approved Release Radar agent action in the disposable project,
   place the ticket into an exact phase Backlog using the current plan revision.
   Expected: the same ticket identity moves from Not placed to the Backlog; stale
   or cross-project placement is rejected without partial change.

### Phase 5B — revision-specific references and recorded impacts

1. Select a ticket with a requirement or decision reference. In **References**,
   open a historical version and its **Reference source**.
2. Expected: exact repository, artifact, link, version, digest, and source status
   are shown; unavailable historical bytes are not replaced with current prose.
3. Choose **Recorded impacts**. Expected: project-scoped linked tickets appear as
   distinct rows, including historical versions, with exact digests.
4. Open one impact and use Back/Forward. Expected: exact row and ticket focus
   restore.
5. In the disposable repository only, change the referenced document after its
   version was recorded and refresh. Expected: changed/stale status is explicit;
   no reference, audit, or receipt is silently rewritten.

### Shared Execution Integration V1

1. In a disposable repository with the exact V1 shared-execution declaration and
   current 0.1.9 plugin, refresh **Shared execution** on Project Overview.
2. Expected: **Compatible with V1** only when the exact declaration, recognized
   plugin capability, checker, repository identity, and accepted catalog agree.
3. Change or duplicate the declaration only in the disposable repository and
   refresh. Expected: a precise incompatible state and recovery guidance. Restore
   the exact declaration afterward.
4. Confirm refresh is observational: it does not edit the repository, accept a
   catalog, install a plugin, or adopt a standard.

### Phase 5C — saved proposals, decisions, refresh, and apply

1. Have an authorized Codex task save a small plan-change proposal against the
   disposable project's current baseline. Open it in Project Plan.
2. Inspect its immutable version, grouped definitions, rationale, baseline, and
   recorded source impacts.
3. Choose **Approve**. Expected: the owner decision is recorded, but the plan does
   not change.
4. Choose **Apply approved version**. Expected: the complete package applies once,
   atomically, and the application record appears.
5. For a second proposal, change its baseline before deciding. Expected: stale
   state blocks decision/apply; **Refresh proposal** creates a new reviewable
   version. Exercise **Reject** on that version and confirm nothing applies.

### Phase 5D — withdrawal, replacement/split, and carried obligations

1. In the disposable project, create and approve a replacement or split proposal
   for a non-Accepted ticket. Review the frozen original placement, successor IDs,
   Delivery Goal carries/drops, and reasons before Apply.
2. Apply it. Expected: successors and their pending tasks are created atomically;
   the original moves to **Retired originals** and disappears from active boards.
3. Select the retained original. Expected: disposition, rationale, frozen last
   phase/lane, successor lineage, original tasks/evidence/references, and coverage
   remain read-only.
4. Open Activity/History from that context and go Back at compact width. Expected:
   the retained original scrolls back into view with focus and detail preserved.
5. Verify invalid partial carry, cycles, cross-project successors, or ambiguous
   split coverage are rejected before any partial write.

### Phase 5E — explicit phase lifecycle

1. In Project Plan, choose a test phase and move it from **Unassessed** to
   **Upcoming**, then **In delivery**, providing a nonblank reason each time.
2. Confirm active phase and viewed phase remain separate; more than one phase may
   be In delivery.
3. Attempt **Completed** while required goals, obligations, or tickets remain
   unresolved. Expected: visible blockers and no transition.
4. After satisfying the disposable phase's completion conditions, complete it.
   Expected: an immutable transition appears in History and the phase becomes
   read-only for planning and delivery writes.
5. Exercise the explicit reopen action, then reload lifecycle. Expected: revision
   advances once, the reason remains visible, and replay does not duplicate history.

### Phase 6A — truthful event-time History

1. Exercise **All**, **Audit**, **Observations**, **Notifications**, **Reviews**,
   and **Completions** filters.
2. Confirm newest-first ordering and separate occurred, observed, and recorded
   times when present. Older events may state that event-time facts are unknown.
3. Inspect exact source, provenance, registration, phase/ticket identity, lane or
   transition facts, and current-context labels. No current value should be
   substituted for missing historical data.
4. Open a recorded ticket in a nonactive phase, then Back. Expected: exact History
   selection, filter, detail, viewport, and focus return.

### Phase 6B — workspace Delivery and Execution Goals

1. In **Delivery**, check terminal and active goals, work with no Delivery Goal,
   and unplaced project work. Inspect criteria, membership, lifecycle, carried
   coverage, readiness, and owner acceptance as separate facts.
2. Open associated placed and unplaced work. Expected: placed work opens the
   all-phase board with the exact goal filter; unplaced work opens Project Plan.
3. In **Execution**, inspect linked, unlinked, and completed persisted observations
   if present. Expected: thread/goal identity, observation time, source provenance,
   freshness, and live availability remain distinct. Unavailable live observation
   does not erase the persisted row or create a Delivery Goal.
4. Use **All goals** on the board to clear an exact goal filter without losing the
   selected ticket. Back/Forward must restore Goals filters, focus, and viewport.

### Phase 6C — revision-bound delivery evidence

1. Have an authorized Codex task record a target for a disposable ticket and add
   representative repository, commit, check, document, build, and installation
   observations using the exact current evidence revision.
2. In the ticket inspector, confirm the recorded target, expected categories,
   observation history, applicability, source availability, and earlier targets.
3. Choose Evidence **Help**. Confirm it says recorded evidence is not live evidence,
   applicability follows exact identity, and evidence is not owner acceptance.
4. Change the recorded target revision and refresh a managed document. Expected:
   prior results remain visible but become stale/unknown as appropriate; refresh
   performs no check, provider request, acceptance, or delivery mutation.
5. Record a correction. Expected: it identifies the superseded observation rather
   than rewriting history.

### Phase 6D — generic task adoption

1. Open a ticket's **Tasks** card and its **Help**. Confirm definitions and
   completion are revisioned, and the guide distinguishes atomic from non-atomic
   adoption, evidence applicability, replay, and recovery.
2. In a new Codex task scoped only to the disposable project, ask it to inventory
   the complete Release Radar delivery state before proposing task reconciliation.
3. Expected: it accounts for every non-Accepted ticket, including unassigned,
   completed-phase, retired, and superseded task history; it presents one exact
   reconciliation and waits for owner approval before writes.
4. Approve a small titled task catalog for one ticket. Expected: only existing
   revision-bound task commands are used, task rows/counts update in the app, and
   History records the result without duplicate receipts on replay.
5. A prior completion may be adopted only with current, available, successful
   evidence that explicitly applies to that ticket and task scope. Uncertain,
   failed, stale, or generic evidence must leave the task Pending.
6. Do not expect Release Radar to execute the tasks or provide Phase 7 Run Guard;
   this slice supports inventory, owner-approved adoption, persistence, and audit.

### Phase 6E — Search, saved views, and shared Help

1. Search across Projects, Delivery Goals, Execution Goals, active/retired tickets,
   current decision references, and History sources. Use a known exact ID and a
   phrase query.
2. Change exact project-registration scope, record domains, and sort. Expected:
   deterministic results and clear partial-results warnings if a domain is
   unavailable. Search itself performs no delivery mutation or file/provider read.
3. Save, load, and delete a named query. This intentionally writes workspace
   saved-query state. Relaunch the app and confirm the supported saved query
   persists with every filter.
4. Open a nonactive-phase ticket result and use Back/Forward. Expected: viewed phase
   changes, active phase does not, and Search state/selection/scroll/focus restore.
5. If two project registrations share a name, confirm scope choices, results, and
   detail show enough stable registration identity to distinguish them.
6. Verify all nine Help topics and their real navigation actions. At compact width,
   scroll through the complete Help content without clipping.

## Potentially destructive checks — optional and last

The following checks affect global application state. Skip them unless you are
prepared to restore the whole app state. Never use **Reset Tracking Data** on the
live owner dataset merely to test it.

1. Create a fresh full backup and verify the package exists.
2. **Reset Preferences…** should restore alert defaults and clear temporary view
   selections while keeping projects, tracking history, plugin receipts, Keychain
   credentials, and saved Search queries.
3. Remove only the disposable project if testing removal. Expected: it moves to
   retained History, cannot mutate, and re-adding the same folder creates a new
   registration without transferring old authority.
4. **Reset Tracking Data…** removes every active and archived project registration.
   Because this is global, do not run it in the ordinary owner environment.
5. **Restore Backup…** replaces supported app state and rotates authority. After
   restore, saved queries remain visible but exact project scope must be deliberately
   selected and resaved before execution. Folder permissions may need reconnection.
6. Confirm a restored older backup retains newer evidence/lifecycle/history only as
   historical facts where supported; it must not silently reauthorize old commands.

## Capture and report a bug

For each failure, record:

1. App version/build `0.1.9 (1)`, correction source `acc7401`, package artifact
   commit `09caafe`, and whether the app was copied from the DMG named above. If
   reporting a guide defect, also include the current documentation commit.
2. Exact project registration, phase, ticket, goal, proposal, reference, evidence,
   or task revision involved. Redact credentials and private document content.
3. Window width (wide or about 760 points), sidebar state, route, filters, and
   whether keyboard, mouse, or accessibility control was used.
4. Numbered reproduction steps, expected result, actual result, and whether any
   mutation committed before the failure.
5. A screenshot showing the whole Release Radar window and the visible error or
   wrong state. For navigation issues, capture before leaving and after Back.
6. Local time of failure and whether relaunch, refresh, or retry changed the result.

Stop immediately if a failure suggests the wrong project/registration, unexpected
owner-data mutation, a partial proposal/evidence/task write, or an authorization
boundary violation. Do not reset or repair live data; report the evidence first.

## Acceptance summary

Report each section as Pass, Fail, or Not exercised. A truthful empty, unavailable,
stale, partial, or recovery state is a pass when its precondition is real and no
identity is guessed. Passing checks do not themselves mark work Accepted, change a
lane, complete a phase, or authorize Phase 7. A clean manual pass does not close
the signed service-test gap recorded above and is not by itself authorization to
accept or promote the build.
