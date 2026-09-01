# MDCP M2C Brief: Central Path Contract and v1 Catalog Preview

**Status:** Proposed and unopened. M2A-M2B acceptance, M1 owner approval, and
separate M2C authorization are required before work.

## Objective and user-visible outcome

Make one Core definition the application source for recognized repository
documentation paths and add a coherent read-only staged-catalog state while
preserving all legacy guidance-v1, onboarding, importer, and evidence behavior.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-002-codex-plugin-lifecycle.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- Accepted M2A-M2B contracts
- `docs/design/agent-driven-delivery-dashboard-design.md`, current Onboarding
  contract

## Scope

In scope:

- central constants for `AGENTS.md`, catalog, indexes, progress, Rekon seed,
  task-brief/handoff/review/evidence/plan/archive collections, versions, and
  managed markers;
- direct Swift consumers in guidance inspection, onboarding, importer, and
  presentation;
- staged valid/invalid catalog observation under exact guidance v1;
- exact agreement tests for bundled Markdown and prompt literals; and
- legacy importer/guidance/onboarding regression coverage.

Out of scope:

- guidance v2 activation, managed evidence identity, import mutation changes,
  plugin installation, owner repository/state mutation, document movement,
  and Issue #1/Task 4B.

## Dependencies and release gate

- M2A-M2B independently accepted.
- UX/Architecture approve the staged-catalog presentation as a refinement of
  existing onboarding status, not a new workflow.

## Anticipated files

- `ReleaseRadarCore/Onboarding/ProjectGuidanceInspection.swift`
- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Core documentation contract files from M2A
- `ReleaseRadar/Projects/OnboardingView.swift`
- `ReleaseRadar/App/AppModel.swift` or the current read-only projection owner
- Bundled Release Radar skill source and only its exact required fixtures
- `ProjectGuidanceAcceptanceTests.swift`, `RekonImportAcceptanceTests.swift`,
  `CodexPluginLifecycleAcceptanceTests.swift`, and focused presentation tests

## Data, security, and privacy

Catalog observation uses the existing authorized project bookmark and M2A
snapshot rules. It performs no repository writes or app mutations. Guidance
inspection remains readable when the catalog is bad. Prompts must not expose
owner paths except through the existing explicit root-binding handoff.

## Test-first strategy

RED/GREEN proves: v1 without catalog remains ordinary exact legacy with no
managed warning; v1 with valid catalog reports staged preview only; a present
but malformed/unsupported/unsafe catalog has an actionable staged-preview
state; catalog staging does not change Rekon preview,
evidence locators, availability, handoff audit, or delivery state; Core paths
match bundled skill and prompt text exactly; `docs/superpowers/` is not a new
recognized application dependency.

## Happy and non-happy behavior

- Legacy v1 stays current under its existing audited-handoff rules.
- A valid v1 catalog can be inspected but cannot drive identity or mutation.
- Bad catalog data cannot make v1 guidance itself unreadable.
- No catalog state causes importer or delivery mutation in this slice.

## Acceptance criteria

- Duplicated Swift literals are removed wherever the Core contract can be used.
- Remaining static literal copies have exact contract tests.
- Existing v1 onboarding/handoff/import behavior is byte/semantics compatible.
- Presentation is one coherent documentation state, not a cross-product table.
- All changes remain read-only with respect to repositories and owner state.

## Reviews and completion evidence

Required post-implementation reviews: Code Review, QA, Architecture, UX,
Security/Privacy, TPM, and Delivery Management. Record exact agreement tests,
legacy regressions, candidate inventory, reviews, and M3A0 eligibility in the
ledger.
