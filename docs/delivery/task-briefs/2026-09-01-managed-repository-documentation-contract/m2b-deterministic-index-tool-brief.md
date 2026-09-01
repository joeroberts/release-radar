# MDCP M2B Brief: Deterministic Index Tool

**Status:** Proposed and unopened. M2A acceptance, M1 owner approval, and
separate M2B authorization are required before work.

## Objective and user-visible outcome

Provide one fixed-purpose repository documentation executable that validates a
catalog and deterministically renders only managed README sections, allowing
agents and normal repository checks to detect index drift without broad search
or uncontrolled file rewriting.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- Accepted M2A catalog API and error contract
- `docs/delivery/progress.md`

## Scope

In scope:

- a separate documentation-tool target or the smallest repository-native
  wrapper supported by the existing Xcode project;
- `check` mode with no writes;
- deterministic index rendering from the M2A snapshot;
- authorized `write` mode that replaces only exact managed markers;
- preservation of human-authored bytes outside managed sections;
- complete prevalidation, per-file atomic replacement, and bounded rollback of
  already replaced index files after a later write failure;
- a check API callable from the repository's ordinary test/check workflow; and
- focused golden/idempotence tests.

Out of scope:

- generic filesystem/shell execution, application SQLite access, agent bridge
  expansion, evidence commands, catalog creation, document moves, CI changes,
  and app UI;
- automatic commits or repository mutation without explicit authorization.

## Dependencies and release gate

- M2A independently accepted at an exact checkpoint.
- Architecture approves the executable boundary and file inventory.
- QA accepts golden fixtures before implementation.

## Anticipated files

- Add `ReleaseRadarDocumentationTool/` with a narrow entry point.
- Modify `ReleaseRadar.xcodeproj/project.pbxproj` and the shared scheme only as
  necessary for the target and repository-native check.
- Optionally add one thin `script/` wrapper that supplies no contract logic.
- Add focused tool tests and expected indexes under the M2A fixture tree.

Do not modify `ReleaseRadarAgentTools`; it is a narrow app mutation helper and
a Task 4B dependency.

## Data, security, and privacy

The tool accepts one explicit repository root, applies M2A no-follow/root
validation, and exposes no network, database, credential, arbitrary command,
or out-of-root write capability. Write mode must write a complete temporary
candidate in the target directory and replace only after validation; failure
leaves every byte unchanged.

## Test-first strategy

RED/GREEN covers stable ordering across shuffled JSON and enumeration order,
golden root/local sections, child navigation and leaf declarations, preservation
of text before/between/after markers, missing/duplicate/malformed markers,
idempotent repeated write, stale-index check failure, per-file atomicity, and
injected late failure with verified bounded restoration of prior index bytes.

## Happy and non-happy behavior

- `check` exits successfully only when validation and every managed section
  match deterministic output.
- `write` changes only managed sections and reports its bounded inventory.
- Missing or invalid catalog, unsafe tree, invalid markers, or write failure
  makes no partial change.

## Acceptance criteria

- Generated sections include purpose, allowed contents, first read, artifact
  ID/path/authority/lifecycle, supersession, archive boundary, and children.
- Every directory is indexed or parent-declared as a leaf.
- Check mode is demonstrably read-only.
- The tool shares Core contract logic rather than duplicating schema/path rules.
- Its check implementation can enforce the real repository through the normal
  test/check workflow once a managed catalog is staged and v2 is the candidate.
- No new dependency or general automation framework is introduced.

## Reviews and completion evidence

Required post-implementation reviews: Code Review, QA, Architecture, TPM,
Delivery Management, and Security/Privacy. Record exact target/files, golden
fixture digest, RED/GREEN evidence, no-change failure proof, reviews, and next
eligible M2C in the delivery ledger.
