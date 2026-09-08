# Phase 3A documentation freshness evidence

- Date: 2026-09-07
- Branch: `codex/phase3a-freshness`
- Baseline: `a4d5e06`
- Controlling brief:
  [`phase3a-freshness-brief.md`](../task-briefs/2026-09-07-phase3a-freshness/phase3a-freshness-brief.md)
- Scope: source candidate and synthetic verification only; no installation,
  owner-project access, catalog acceptance, plugin/cloud mutation, or live
  application-state mutation occurred.

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

This proves accessibility activation reaches and opens the shared native picker
and that cancellation is non-mutating. A successful external folder
selection granting sandbox access and completing real bookmark renewal was not
performed in this synthetic signed-host route. Successful exact-root renewal,
wrong-root rejection, invalid-catalog preservation, audit count, and identity
preservation are covered by the synthetic Core/AppModel integration tests, but
the full signed selection-to-renewal journey remains an outstanding Phase 3
verification gap. Separate keyboard activation was not exercised by this proof.

The simplest supported continuation would reuse the earlier stripped-entitlement
signed XCTest host and drive the already-rendered recovery button and native
panel. That host vanished with the deleted worktree. The current ordinary Debug
XCTest host carries the repository's broad test-only absolute-path read
exception, so it is not acceptable substitute proof for an isolated successful
selection-to-bookmark journey. Recreating the specialized host or adding new
panel/keyboard automation would be bespoke harness work outside this correction
scope. Both gaps therefore remain explicit rather than being inferred from the
synthetic renewal tests.

Two earlier blocking-modal harness attempts were stopped after hanging; their
exact synthetic host PIDs `76348` and `76804` and the associated Xcode runner were
confirmed absent before the final run. The final test uses the real panel's
nonblocking API and exits normally.

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
- `/Users/Shared/ReleaseRadar-Phase3A-SignedPicker.QxfqrP`, retained from the
  earlier signed-picker work

The repository evidence document and four screenshots above are the durable
artifacts. Catalog/index integration remains the orchestrator's owned follow-up.
