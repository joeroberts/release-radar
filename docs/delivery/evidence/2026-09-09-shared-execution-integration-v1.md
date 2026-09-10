# Shared Execution Integration V1 — source evidence

**Date:** 2026-09-09

**Scope:** authorized local source candidate only

**Controlling design:** [Shared Execution Integration V1](../../design/shared-execution-integration-v1-design.md)

**Implementation plan:** [Shared Execution Integration V1 source implementation plan](../task-briefs/2026-09-09-shared-integration/implementation-plan.md)

## Delivered source behavior

- The bundled Release Radar plugin is version `0.1.8` and contains the exact
  `$release-radar:shared-execution` V1 skill. Exact `0.1.7` recognition remains,
  but only the exact `0.1.8` version/digest pair advertises shared-execution
  standard `1`.
- `ReleaseRadarDocumentationTool diagnose --root <exact-root> --format json`
  adds the versioned diagnostic envelope without changing the existing
  `check`, `write`, or help contracts.
- Shared-execution declaration inspection is read-only, exact-root-bound,
  no-follow, regular-file, bounded, and stability-checked. The pure reducer
  covers all nine reviewed compatibility states without SemVer inference or
  persistence.
- The existing project documentation observation now carries repository,
  declaration, exact plugin capability, and direct-result evidence through its
  existing identity/generation boundary. Plugin lifecycle status changes and
  explicit project refresh invalidate and republish the active project result.
- Project Overview presents compatibility as a read-only Rekon panel. Its only
  control refreshes observation; install, adoption, catalog acceptance, and
  consumer writes remain separate owner actions.

## Direct validation

All native tests used the sanitized environment, isolated DerivedData at
`/tmp/release-radar-sei-red.5NGrlB/DerivedData`, and the repository's synthetic
test hosts. The owner's installed app, SQLite, Keychain, plugin installation,
consumer repositories, and external services were not used.

| Check | Direct result |
| --- | --- |
| Final affected source/UI suite | `101 passed`, `2 skipped`, `0 failed` in `final-affected-candidate.xcresult`. The two skips are the existing environment-gated signed native folder-picker cases. |
| Transport boundary | The one test that really registers/unregisters an `SMAppService` was excluded because helper registration was not authorized. All included transport cases use injected service and remote stubs. |
| Compatibility UI matrix | All nine reviewed states, direct-result vocabulary, absent mutation controls, refresh, focus, disabled-checking behavior, and minimum control sizing passed at 620 and 1100 points. |
| Integrated Project Overview | Existing documentation states rendered at 620 and 1100 points with Shared execution checking/refresh content in the real overview hierarchy. |
| Diff hygiene | `git diff --check` passed after the final candidate run and is repeated at the scoped commit boundary. |

The final affected suite covers `SharedExecutionSkillContractTests`,
`RecognizedPluginCapabilityTests`, `RepositoryDocumentDiagnosticTests`,
`RepositoryDocumentIndexTests`, `DocumentationToolInstallationTests`,
`SharedExecutionCompatibilityTests`, `CodexPluginLifecycleAcceptanceTests`,
the safe `CodexPluginLifecycleTransportTests`, `DocumentationObservationTests`,
`ProjectDocumentationRenderingTests`, and the focused AppModel plugin-observation
refresh case.

## Independent review and corrections

The first independent review identified four required source corrections. The
local correction candidate now:

- binds a managed compatibility result to the accepted project/root binding and
  exact repository ID, catalog version, and digest instead of trusting a later
  diagnostic identity;
- invalidates every active project's documentation generation before awaiting
  plugin-triggered refresh, so an older in-flight result cannot win;
- maps a valid changed catalog to pending acceptance; and
- carries a closed mismatch reason into actionable UI recovery while retaining
  only recognized, bounded repository-checker error codes in direct results.

The focused RED bundle is
`review-corrections-red.xcresult`. After correction, the focused race regression
passed `1/1` in `review-race-corrected-green.xcresult`. The final affected
correction suite passed `20`, skipped the same `2` environment-gated native
picker cases, and failed `0` in `review-corrections-affected.xcresult`. The
rendering portion repeated all nine states at 620 and 1100 points with no
accessibility or screenshot assertion failure. The same reviewer rechecked these
corrections within the original scope.

That re-review found one residual interval-mismatch case within the same
identity boundary: a valid unaccepted catalog diagnostic from another
repository could still appear pending. `review-catalog-identity-red.xcresult`
reproduced it. The bounded correction requires the diagnostic repository to
match the captured project/root binding while still allowing a same-repository
version or digest change to remain pending. Both boundary cases passed `2/2` in
`review-catalog-identity-green.xcresult`; the containing observation suite then
passed `9`, skipped the same `2` picker cases, and failed `0` in
`review-catalog-identity-affected.xcresult`. The same independent Astra High
reviewer (`01a08889-1c24-7d90-9c46-a5846b96c125`) passed exact source commit
`0c4c08969c7dd7d869a69acf3d5b0e40e6e89bba`, closing all four Required findings.
The authorized local source outcome is complete; writer and reviewer hosts are
stopped. This closeout adds documentation only.

## Visual comparison

The synthetic native views were compared with the approved Goals compact and
Settings mockups. They retain the established dark Rekon palette, blue section
borders, semantic success/warning/danger color, typography hierarchy, and
stacked compact reading order. Screenshot review found a compact header overflow
in the first implementation; the final stable stacked header removes the
clipping at both widths. No design deviation was required.

- [Compatibility detail, compact](shared-execution-v1-compatibility-compact.png)
- [Project Overview, compact](shared-execution-v1-overview-compact.png)
- [Project Overview, wide](shared-execution-v1-overview-wide.png)

These are synthetic test-host renders. They prove the source presentation and
interaction boundary exercised by the tests, not installed-app behavior or a
runtime consumer pilot.

## Known non-candidate conditions

A separate `ManagedGuidanceCompatibilityTests` run produced `9 passed` and
`2 failed`:

1. At the source-only checkpoint, the actual-repository conformance case reported
   a new canonical screenshot as uncatalogued. The serialized metadata integration
   registered all four new evidence artifacts and regenerated the index; the
   repository documentation check now passes. The earlier test result is retained
   as evidence of that pre-integration state, not a current catalog defect.
2. The disposable-real-repository case still expects `staleIndex`, but its
   copied documentation tree now reaches a different historical fixture
   condition. This failure was reported before the final source candidate and
   is not caused by Shared Execution source behavior.

Repository documentation validation and `git diff --check` passed after the
serialized catalog/index and contract updates. The existing shared-design artifact
retains its stable identity, proposed/supporting metadata and no-checksum policy;
source authorization does not silently promote it to a controlling adoption record.
Independent review of the corrected combined source candidate is complete.
This verification does not authorize a source runtime
pilot, plugin installation, consumer adoption, push, PR, or merge.

## Retained temporary evidence

The test result bundles, exported intermediate screenshots, and isolated build
products remain under `/tmp/release-radar-sei-red.5NGrlB/`. The three screenshots
linked above are the canonical durable visual evidence. No temporary evidence
was deleted because cleanup was not authorized.
