# Release Radar repository catalog v1 reference

This reference ships with Release Radar. The installed checker is
`/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarDocumentationTool`;
this file is `Contents/Resources/catalog-v1.md` inside that app. Copied app
handoff prompts use the actual running bundle path. Run the checker with
`--help` to locate this reference in a relocated app.

The native checker is the executable contract: it validates both JSON metadata
and the actual filesystem, links, checksums and generated indexes. A JSON-only
schema cannot establish those properties. No source checkout, Xcode or separate
dependency installation is needed.

## Commands and authority

```sh
"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarDocumentationTool" check --root "/absolute/authorized/repository"
"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarDocumentationTool" write --root "/absolute/authorized/repository"
```

`check` is read-only. `write` requires explicit repository-write authorization
and changes only managed blocks in existing catalogued collection indexes; it
does not create a catalog, ledger, missing index or missing marker pair. Both
return 0 on success, 1 on validation/I/O failure, and 64 for invalid arguments.
Neither operation changes AGENTS.md, binds a repository, accepts a catalog,
adopts evidence, writes SQLite, or changes ticket/phase state. A valid changed
catalog remains pending until the app accepts its authorized transition.

Prepare missing documentation only under separate explicit owner authorization.
Preserve existing instructions and artifact identities. Do not replace a real
catalog with the example below or infer delivery status from documentation.

## JSON fields

The catalog lives at `docs/catalog.json`. Required top-level fields are
`version` (integer 1), `repositoryID` (a stable UUID), `retiredArtifactIDs`
(array of retired artifact IDs), `collections` and `artifacts` (arrays).
Generate the repository UUID once; never replace an existing one. Artifact and
collection IDs are nonempty stable identifiers using letters, digits, `.`, `_`,
`-` or `:` (maximum 128 UTF-8 bytes); retired artifact IDs cannot be reused.

Each collection has `collectionID`, `path`, `purpose`, nonempty string arrays
`allowedContents` and `prohibitedContents`, and boolean `isLeaf`. Non-root
collections have `parentCollection` naming the immediate parent. Non-leaf
collections require `indexArtifactID` naming their `README.md` collection index.
Leaf collections have no index and no child collections; their parent index
renders their contents. Optional `firstRead` names a non-archived artifact in
that collection. Optional `archiveDestination` names another collection without
controlling artifacts; archive destinations must not form cycles.

Each artifact requires:

| Field | Value |
| --- | --- |
| `artifactID` | Stable artifact identifier |
| `path` | Unique repository-relative path under `docs/` |
| `kind` | `document`, `collectionIndex`, `designAsset`, `verificationEvidence`, `checksumManifest` |
| `lifecycle` | `proposed`, `active`, `completed`, `superseded`, `archived` |
| `authorityLevel` | `controlling`, `supporting`, `nonAuthoritative` |
| `parentCollection` | Collection containing the file directly |
| `supersedes` | Array of existing or retired artifact IDs; no cycles |
| `applicationSensitivity` | Nonempty unique array: `guidance`, `importer`, `evidence`, `prompt`, `fixture`, `none`; `none` cannot combine with others |
| `checksum` | Object with `policy`: `notApplicable` or `required` |

Only controlling artifacts have `authorityRole`; it is required, unique among
controllers, and follows the ID syntax. Controllers must be active. Archived
artifacts must be non-authoritative. A required checksum also has
`manifestArtifactID`, naming a different `checksumManifest` artifact. Manifest
lines are SHA-256, two spaces, then the repository-relative artifact path.
Mutable plans, briefs, indexes, reviews and progress use `notApplicable`.

All files under `docs/` except the catalog itself must be catalogued, and every
directory must have a collection. The root collection is non-leaf `docs` with
index artifact `docs/README.md`. Paths must be relative, normalized, unique
case-insensitively and free of traversal, encoded separators, symlinks and
non-regular files. The checker also rejects prohibited content, broken active
links, unlabelled active-to-archived references and checksum mismatches.
AGENTS.md is outside `docs/`: valid path-based evidence for it need not have a
catalog entry and must not be silently converted to managed evidence.

Accepted catalog transitions preserve repository ID and artifact kind. Allowed
lifecycle transitions are proposed→active, active→completed (documents/evidence),
active→superseded (with an active replacement), and completed→archived (moved to
the declared archive collection). Removed non-controlling IDs become retired;
controlling artifacts cannot simply be deleted. Catalog acceptance is an app
operation separate from this checker. `transitionalSubtree` is a reserved,
existing-history-only exception; omit it for new catalogs and never recreate
`docs/superpowers/`.

## Minimal preparation example

For a new, otherwise empty `docs/` tree only, create `docs/README.md` containing
a human title and exactly these markers on separate lines:

```markdown
# Project documentation

<!-- release-radar-docs:v1:start -->
<!-- release-radar-docs:end -->
```

Create `docs/delivery/progress.md` with the owner's actual delivery state. The
example UUID must be replaced for a real new repository. This catalog covers
exactly those two files; extend it to cover every existing file and collection.

```json
{
  "version": 1,
  "repositoryID": "4ae2a348-8e49-44f7-a4f4-86724169006c",
  "retiredArtifactIDs": [],
  "collections": [
    {"collectionID": "docs", "path": "docs", "purpose": "Project documentation", "allowedContents": ["Documentation"], "prohibitedContents": ["Secrets"], "isLeaf": false, "indexArtifactID": "docs-index", "firstRead": "docs-index"},
    {"collectionID": "delivery", "path": "docs/delivery", "parentCollection": "docs", "purpose": "Current delivery state", "allowedContents": ["Progress ledger"], "prohibitedContents": ["Owner data"], "isLeaf": true, "firstRead": "progress"}
  ],
  "artifacts": [
    {"artifactID": "docs-index", "path": "docs/README.md", "kind": "collectionIndex", "lifecycle": "active", "authorityLevel": "supporting", "parentCollection": "docs", "supersedes": [], "applicationSensitivity": ["none"], "checksum": {"policy": "notApplicable"}},
    {"artifactID": "progress", "path": "docs/delivery/progress.md", "kind": "document", "lifecycle": "active", "authorityLevel": "controlling", "authorityRole": "delivery.current-state", "parentCollection": "delivery", "supersedes": [], "applicationSensitivity": ["none"], "checksum": {"policy": "notApplicable"}}
  ]
}
```

After authorized preparation, run `write` once to generate the index blocks,
then `check`. No guidance activation, repository binding or catalog acceptance
is implied by either result. Use the existing installed Release Radar skill
only for its separately authorized handoff or managed-documentation operation.
