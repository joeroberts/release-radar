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

This covers external invalidation and repair, invalid-catalog renewal,
observation side-effect absence, shared Overview/evidence/health state,
activation and monitor refresh, coalescing, stale-result rejection, lifecycle
invalidation, service replacement, action presentation, and wide/compact
rendering.

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

This proves accessibility activation reaches and opens the shared native picker
and that cancellation is non-mutating. A successful external folder
selection granting sandbox access and completing real bookmark renewal was not
performed in this synthetic signed-host route. Successful exact-root renewal,
wrong-root rejection, invalid-catalog preservation, audit count, and identity
preservation are covered by the synthetic Core/AppModel integration tests, but
the full signed selection-to-renewal journey remains an outstanding Phase 3
verification gap. Separate keyboard activation was not exercised by this proof.

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

## Retained temporary outputs

No temporary output was deleted. The retained non-authoritative artifacts are:

- `build/phase3a-verify/`
- `build/phase3a-signed-host/`, including the synthetic test-only entitlements
  and `.xctestrun`
- `build/phase3a-signed-picker-final.xcresult`
- `build/phase3a-evidence-export/`
- `build/phase3a-test-fixtures/` from the superseded fixture location
- `/Users/Shared/ReleaseRadar-Phase3A-SignedPicker.QxfqrP`

The repository evidence document and four screenshots above are the durable
artifacts. Catalog/index integration remains the orchestrator's owned follow-up.
