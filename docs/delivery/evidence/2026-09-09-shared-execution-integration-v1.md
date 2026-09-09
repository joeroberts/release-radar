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

1. The actual-repository conformance case currently reports the new canonical
   screenshot as uncatalogued. This is expected until the parent-owned
   `docs/catalog.json` and generated indexes are updated in the serialized
   metadata handoff.
2. The disposable-real-repository case still expects `staleIndex`, but its
   copied documentation tree now reaches a different historical fixture
   condition. This failure was reported before the final source candidate and
   is not caused by Shared Execution source behavior.

Repository documentation validation must be rerun after the parent-owned
catalog/index update. One fresh independent review of the immutable combined
candidate also remains required. Neither condition authorizes a source runtime
pilot, plugin installation, consumer adoption, push, PR, or merge.

## Retained temporary evidence

The test result bundles, exported intermediate screenshots, and isolated build
products remain under `/tmp/release-radar-sei-red.5NGrlB/`. The three screenshots
linked above are the canonical durable visual evidence. No temporary evidence
was deleted because cleanup was not authorized.
