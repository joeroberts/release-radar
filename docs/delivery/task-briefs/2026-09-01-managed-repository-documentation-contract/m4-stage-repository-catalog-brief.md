# MDCP M4 Brief: Stage This Repository's Catalog In Place

**Status:** Proposed and unopened. M2-M3 acceptance, M1 owner approval, and
separate M4 authorization are required before repository changes.

## Objective and user-visible outcome

Inventory, classify, and catalog this repository's existing durable `docs/`
tree at its current paths, then generate complete indexes while guidance stays
v1 and all documents, evidence, and owner state remain unmoved. The two held
content artifacts remain byte-exact and accepted checksum entries remain intact.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- Accepted M2-M3 candidate and repository tool
- `AGENTS.md` and `docs/delivery/progress.md`

## Scope

In scope:

- temporary execution inventory for every eligible `docs/` file/asset, inbound
  active links, checksums, authority, lifecycle, app sensitivity, evidence
  candidate, and parent index;
- owner decisions for any unresolved authority conflict;
- `docs/catalog.json` at existing canonical paths;
- root and local README managed sections, with leaf declarations;
- repository-side exact evidence-candidate analysis with no owner-state access;
  and repository check mode.

Out of scope:

- file moves, guidance v2, evidence adoption, app source/store changes, owner
  data, archive narrative rewrite, `progress.md` compaction, `AGENTS.md` rules,
  deletion, or GitHub issue changes.

## Dependencies and release gate

- M2-M3 terminal acceptance and exact compatible tool candidate.
- Stable active-work checkpoint and separate owner authorization.
- Explicit owner resolution of authority conflicts that cannot be derived from
  accepted artifacts.

## Anticipated files

- Add `docs/catalog.json`.
- Add/update only README indexes required for the current tree.
- Update applicable checksum manifests only for authorized new indexes if the
  accepted checksum policy requires them.
- Use temporary inventory outside durable repository state and do not create a
  competing ledger.

`docs/superpowers/` remains in place under one tested transitional exception.
`docs/README.md` directly enumerates that subtree, its `plans/` and `specs/`
leaf collections, and every contained artifact without adding a file there.
The exception permits no new content and expires at M7.

## Data, security, and privacy

Use repository reads only. Live persisted-evidence inventory belongs to M6A.
Do not launch/install the app, access owner state, or mutate storage. Do not
include absolute owner paths or bookmark bytes in the catalog/indexes. No file
may be deleted or reclassified without evidence and owner decision when
authority is ambiguous.

## Test-first/check strategy

Before repository writes, run the accepted tool against a small proposed
catalog fixture and obtain expected failure on the uncatalogued real tree.
After authorized catalog/index writes, check completeness, deterministic
second-render identity, links, checksums, controller uniqueness, parent/leaf
coverage, and guidance-v1 staged-preview behavior. Compare held file bytes with
the accepted M0 hashes for the evidence JSON and Task 2A brief. Verify the
accepted pre-M1 checksum-manifest entries remain byte-identical while permitting
only separately authorized appended entries.

## Happy and non-happy behavior

- Every eligible current file has one stable ID and current path.
- Historical wording remains untouched and is overridden by catalog authority.
- Unresolved classification stops the affected catalog entry; it is not guessed.
- No catalog/index change alters app or delivery state.

## Acceptance criteria

- Exact current paths are catalogued without any move.
- Every directory is indexed or declared a leaf.
- `docs/superpowers/` remains transitional and no new dependency is added.
- Guidance remains v1; catalog use is read-only preview only.
- The held evidence JSON and Task 2A brief match their accepted whole-file
  hashes. Accepted pre-M1 checksum entries remain intact; the shared manifest
  may receive only separately authorized appended entries and is not
  regenerated to resolve the incident.
- Final diff contains catalog/index files, permitted checksum updates, and the
  coordinator-owned progress entry only.

## Reviews and completion evidence

Required reviews: Planning, Architecture, QA, Delivery Management, TPM, and
Security/Privacy. Record temporary-inventory disposition, owner decisions,
tool checks, held-file/manifest comparison, repository candidate analysis,
exact diff, and
M5 eligibility in `docs/delivery/progress.md`.
