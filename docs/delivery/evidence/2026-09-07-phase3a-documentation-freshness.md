# Phase 3A documentation freshness evidence

- Date: 2026-09-07
- Updated: 2026-09-08
- Branch: `codex/phase3a-freshness`
- Baseline: `a4d5e06`
- Controlling brief:
  [`phase3a-freshness-brief.md`](../task-briefs/2026-09-07-phase3a-freshness/phase3a-freshness-brief.md)
- Scope: source candidate, synthetic verification, and owner-assisted signed
  native-folder acceptance only; no installation, owner-project access,
  catalog acceptance, plugin/cloud mutation, or live application-state mutation
  occurred.

## Delivered behavior

One registration/root/binding-scoped observation now supplies project Overview,
managed evidence, and documentation health. A refresh immediately withdraws the
prior success state, coalesces concurrent reads, rejects superseded service or
identity results, and publishes one meaningful observation time. Active projects
are rechecked on load, activation, authorized recovery, and a bounded one-second
filesystem monitor. Archive, removal, and service replacement invalidate the
observation and stop its monitor.

The observer resolves the existing bookmark once, uses the existing bounded
no-follow catalog and managed-evidence readers, and publishes an in-memory result.
Observation does not accept a catalog, rewrite evidence availability, mark a
bookmark stale, audit, or mutate delivery state.

Root-unavailable and stale-root presentations expose an accessible **Restore
folder access** action. The shared native folder panel selects one existing
directory and has no relocation controls. Renewal accepts only the exact captured
canonical root and rechecks registration, root row, path, binding, lifecycle, and
store identity before replacing the bookmark in one audited transaction. It does
not accept or repair an invalid or pending catalog; the refreshed observation
continues to show that remaining state.

Recovery now synchronously retires the prior documentation-authorization graph
and fences its store before installing a distinct replacement graph. Same-store
recovery drains any already-started renewal before rebuilding that graph.
An invalidated observation is treated as superseded work rather than missing
documentation, and every projection preparation remains pinned to its captured
store and observer. Consequently, an older reload cannot overwrite a newer
activation refresh or publish a failure for intentional invalidation.

## Direct verification

The focused test run used the repository's synthetic XCTest host and passed 94
tests with 2 intentional native-only skips and no failures:

```text
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination platform=macOS -derivedDataPath build/phase3a-verify \
  -only-testing:ReleaseRadarTests/DocumentationObservationTests \
  -only-testing:ReleaseRadarTests/ProjectDocumentationRenderingTests/testPhase3ADocumentationCheckingAndFolderRecoveryAtWideAndCompactWidths \
  -only-testing:ReleaseRadarTests/ManagedEvidencePresentationTests \
  -only-testing:ReleaseRadarTests/AppRouteTests

Result: Passed — 94 passed, 2 skipped, 0 failed
Result bundle: build/phase3a-verify/Logs/Test/Test-ReleaseRadar-2026.09.07_22-48-05--0400.xcresult
```

This historical run covers external invalidation and repair, invalid-catalog renewal,
observation side-effect absence, shared Overview/evidence/health state,
activation and monitor refresh, coalescing, stale-result rejection, lifecycle
invalidation, service replacement, action presentation, and wide/compact
rendering.

The result bundle above vanished when the earlier worktree was deleted; it was
not moved by this correction pass. The current checkout therefore retains the
recorded outcome but not that historical bundle.

### Required race-correction verification

The directly affected checks were rerun after adding controlled interleavings
for recovery versus folder renewal and activation versus an older projection
reload:

```text
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination platform=macOS \
  -derivedDataPath build/phase3a-corrections-verify \
  -only-testing:ReleaseRadarTests/DocumentationObservationTests \
  -only-testing:ReleaseRadarTests/AppRouteTests/testProjectHealthReauthorizesOnlyTheExactSavedFolderAndRetainsCatalogFailure \
  -only-testing:ReleaseRadarTests/AppRouteTests/testRecoverySupersedesPendingDocumentationFolderRenewalBeforeReplacingServices \
  -only-testing:ReleaseRadarTests/AppRouteTests/testActivationRefreshSupersedesInvalidatedProjectionPreparation

Result: Passed — 7 passed, 1 intentional signed-picker skip, 0 failed
Result bundle: build/phase3a-corrections-verify/Logs/Test/Test-ReleaseRadar-2026.09.07_23-53-14--0400.xcresult
```

The recovery race gates the old onboarding bookmark validation, completes service
replacement with the same project identity, then releases the old operation. It
verifies a stale error, no success result, no bookmark or audit mutation in the
retired store, and no mutation in the active replacement store. The activation
race completes generation G+1 before releasing G and verifies that G is
superseded without replacing G+1 documentation, evidence, or error state.

One earlier rerun of the freshness integration test failed while copying its
synthetic fixture into the repository `build/` directory because the ordinary
sandboxed host correctly denied that write. The fixture was moved to the
sandbox-authorized per-user test location already used by repository tests. The
same test then passed in the isolated rerun and in the 94-test focused run. This
was a test-location defect, not a product freshness failure.

### Signed native picker proof

A fresh Apple Development-signed synthetic host used production app sandbox,
application-group, user-selected read/write, and network-client entitlements,
plus only the three XCTest Mach lookup names and `get-task-allow`. Entitlement
readback contained no absolute-path or home-relative filesystem exception.
Strict deep signature validation passed.

Using the current host's numeric PID, the gated XCTest found the error-state
**Restore folder access** accessibility button, performed its AX press action,
observed a real shared `NSOpenPanel`, cancelled it, and verified that the stale
bookmark and audit count were unchanged:

```text
xcodebuild test-without-building \
  -xctestrun build/phase3a-signed-host/Build/Products/ReleaseRadar-Phase3A-no-broad-filesystem.xctestrun \
  -destination platform=macOS,arch=arm64 \
  -only-testing:ReleaseRadarTests/DocumentationObservationTests/testSignedNativeFolderPickerOpensFromDocumentationErrorViaAX \
  -resultBundlePath build/phase3a-signed-picker-final.xcresult

Result: Passed — 1 passed, 0 skipped, 0 failed (1.050 seconds)
```

The signed-picker result bundle and its synthetic host directory vanished with
the earlier worktree and were not moved by this correction pass. This section
records the completed historical check; its bundle is not present in the current
checkout.

That historical check proves accessibility activation reaches the shared native
picker and cancellation is non-mutating. Its successful selection-to-renewal and
keyboard-input gaps were closed on 2026-09-08 with a fresh retained host at
`build/phase3a-native-journey/`.

The current host was built from the correction candidate and then signed with
the same restricted test-runtime entitlement shape: production sandbox,
application group, user-selected read/write, network client, `get-task-allow`,
and only the three XCTest Mach lookup names. Fresh entitlement readback again
showed no absolute-path or home-relative filesystem exception, and strict deep
signature verification passed.

### Owner-assisted signed selection and renewal

The owner launched `xcodebuild test-without-building` from Terminal using the
prepared `.xctestrun` and absolute paths supplied by this delivery task. The
test host printed its exact numeric PID, window title, expected folder, and
instructions. The owner—not automation, `osascript`, or a synthetic event—then
supplied the keyboard Space input in the ReleaseRadar test window and selected
`/Users/Shared/ReleaseRadar-Phase3A-SignedPicker.QxfqrP` through the real shared
`ProjectFolderAccessPanel.choose()` `NSOpenPanel`.

The gated test used only the current XCTest host PID to locate the exact
**Restore folder access** accessibility button. Before printing readiness, the
final harness focused that button through its accessibility element and read
back `kAXFocusedAttribute == true`. A local `NSEvent` monitor observed the
owner's real Space key while that same button remained focused. The resulting
folder URL was passed through the real `AppModel.restoreDocumentationFolderAccess`
path.

```text
xcodebuild test-without-building \
  -xctestrun build/phase3a-native-journey/Build/Products/ReleaseRadar-Phase3A-user-assisted-no-broad-filesystem.xctestrun \
  -destination platform=macOS,arch=arm64 \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/DocumentationObservationTests/testUserAssistedSignedNativeFolderPickerKeyboardSelectionRenewsBookmarkWithoutChangingIdentityOrCatalog \
  -resultBundlePath build/phase3a-native-user-assisted-rerun-4.xcresult

Result: Passed — 1 passed, 0 skipped, 0 failed
Result bundle: build/phase3a-native-user-assisted-rerun-4.xcresult
```

The passing test verifies that the stale bookmark changes from `1` to `0`,
exactly one `Restore project folder access` audit is added, and the sole captured
registration, request generation, root ID/path, repository identity, accepted
catalog bytes, digest, and version remain unchanged. The separately retained
cancel test continues to prove that cancellation is non-mutating.

The coordinated reruns exposed only acceptance-harness and instruction defects:

- The first command used a different checkout's relative build path and failed
  before any test host launched. Subsequent commands used absolute prepared
  paths.
- The first launched journey selected a folder other than the captured root.
  Product validation rejected it before bookmark or audit mutation. The test
  was corrected to report both the raw and canonical picker paths on failure.
- The next run selected and renewed the correct folder and produced no
  registration, root, binding, catalog, or audit assertion failures, but the
  keyboard observer compared dynamic accessibility wrappers too strictly.
- The following run again completed the renewal, but semantic element matching
  still depended on the owner's macOS keyboard navigation having established
  button focus.
- The final bounded correction focused and read back the exact button before
  readiness and checked its focused attribute when Space arrived. A one-second
  no-input preflight reached readiness and then intentionally timed out; the
  subsequent owner-assisted run passed in full.

No production entitlement, target, framework, owner project, application
database, catalog acceptance, `CGEvent`, broad test-host filesystem access, or
installation was added or used for this journey. No script drove the picker or
keyboard. One read-only `osascript` diagnostic was mistakenly invoked while
checking whether the retained folder was an alias; it returned no useful output
and was not used as acceptance evidence. Because the final proof requires
deliberate owner input, it remains gated by
`PHASE3A_SIGNED_PICKER_SUCCESS_FOLDER` and is skipped during ordinary automated
test runs.

Two earlier blocking-modal harness attempts were stopped after hanging; their
exact synthetic host PIDs `76348` and `76804` and the associated Xcode runner were
confirmed absent before the historical cancel proof. The current user-assisted
test uses the real panel's modal API on the main actor and exits normally after
the owner responds. Final host PID `27429` was absent after result readback.

## Visual evidence

The four canonical screenshots were rendered by
`ProjectDocumentationRenderingTests.testPhase3ADocumentationCheckingAndFolderRecoveryAtWideAndCompactWidths`
and inspected for readable status hierarchy, unambiguous recovery, and responsive
layout:

- [Checking — wide](phase3a-checking-wide.png)
- [Checking — compact](phase3a-checking-compact.png)
- [Folder recovery — wide](phase3a-folder-recovery-wide.png)
- [Folder recovery — compact](phase3a-folder-recovery-compact.png)

## Temporary-output status

No temporary output was deleted by this correction pass. These earlier
worktree-scoped paths are absent because the earlier worktree was deleted; they
were not moved:

- `build/phase3a-verify/`
- `build/phase3a-signed-host/`, including the synthetic test-only entitlements
  and `.xctestrun`
- `build/phase3a-signed-picker-final.xcresult`
- `build/phase3a-evidence-export/`
- `build/phase3a-test-fixtures/` from the superseded fixture location

Current non-authoritative outputs retained in this checkout are:

- `build/phase3a-corrections-red/`, including the intentional failing red runs
- `build/phase3a-corrections-verify/`, including the passing scoped result bundle
- `build/phase3a-native-journey/`, including the signed host, stripped
  test-runtime entitlements, focused `.xctestrun` files, and focus-preflight
  copy
- `build/phase3a-native-*.xcresult`, including readiness, expected diagnostic
  failures, the intentional no-input focus-preflight timeout, and the final
  passing `phase3a-native-user-assisted-rerun-4.xcresult`
- `/Users/Shared/ReleaseRadar-Phase3A-SignedPicker.QxfqrP`, retained from the
  earlier signed-picker work

The repository evidence document and four screenshots above are the durable
artifacts. Its existing catalog entry uses `checksum.policy: notApplicable`,
and no path, lifecycle, authority, or navigation metadata changed; catalog and
generated-index edits are therefore unnecessary for this update.
