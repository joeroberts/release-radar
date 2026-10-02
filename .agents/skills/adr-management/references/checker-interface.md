# Shared ADR checker interface

The checker is shared by `$adr-management` and `$development-exception`:

```sh
python3 .agents/skills/adr-management/scripts/adr_checker.py snapshot \
  --repository WIKI_CLONE --wiki-repository WIKI_URL --revision COMMIT \
  --ticket ISSUE_URL --operation NAME --scope SCOPE [--scope SCOPE ...] \
  [--id ADR-NNN ...]

python3 .agents/skills/adr-management/scripts/adr_checker.py transition \
  --repository WIKI_CLONE --wiki-repository WIKI_URL \
  --prior-revision COMMIT --candidate-revision COMMIT \
  --ticket ISSUE_URL --operation NAME --scope SCOPE [--scope SCOPE ...] \
  --authorization FILE [--initial-catalog]

python3 .agents/skills/adr-management/scripts/adr_checker.py render-index \
  --repository WIKI_CLONE --revision COMMIT

python3 .agents/skills/adr-management/scripts/adr_checker.py read-contract \
  --repository WIKI_CLONE \
  --contract adr-lifecycle\|development-exception

python3 .agents/skills/adr-management/scripts/adr_checker.py exception \
  --repository WIKI_CLONE --wiki-repository WIKI_URL --revision COMMIT \
  --ticket ISSUE_URL --operation NAME --scope SCOPE [--scope SCOPE ...] \
  --diagnostics FILE --issue-snapshot FILE --trusted-approval FILE
```

`snapshot`, `transition`, and `exception` resolve the canonical remote HEAD and
read named commits using Git object commands. They require the repository's
`origin` URL to match `--wiki-repository`. `snapshot` requires `--revision` to
equal that remote HEAD. `transition` instead requires `--prior-revision` to equal
the remote HEAD; its candidate may be an unpublished local descendant so it can
be validated before publication. The Release Radar catalog additionally requires
the exact canonical identity
`https://github.com/joeroberts/release-radar.wiki.git`.

`read-contract` requires that canonical origin and reads only accepted commit
`38cc05e4300df71faa16dfcdd234fe0f8cd46124`. `adr-lifecycle` requires
`Contract-ADR-Lifecycle-and-Integrity.md` as mode `100644`, blob
`2a0df264aa8a550476dcdb6981bd390210a0e54c`; `development-exception` requires
`Scoped-Development-Exceptions-Contract.md` as mode `100644`, blob
`d9c16ee8f4036b6b0876b4d2946d2072f635478f`. It writes only those verified
bytes. Missing, changed, or unsafe objects exit `2` with no contract bytes. Live
rendered or current Wiki contract text is not an operational policy source.

`--initial-catalog` is limited to the authorized one-time cutover from a prior
revision that has no `ADR-Catalog.json`. It fails if the prior revision already
has a catalog and requires the authorization input to list `add` for every
candidate record. It validates the candidate's complete inventory, normalized
records, fixed baselines, and derived index; it does not infer preservation or
approval from the absence of prior structured state. Later missing prior state
remains `ADR_TRANSITION_UNAUTHORIZED` or `ADR_BASELINE_UNAVAILABLE` as applicable.

## Result

Standard output contains one JSON object. `schemaVersion` is `1`; `status` is
`verified`, `blocked`, or `proceeding_under_exception`. The object also contains
the ticket, operation, Wiki identity, read revision, selected IDs, scopes,
diagnostics, and exception details when applicable. Diagnostics contain a stable
contract code and message plus the relevant ID, path, expected value, or actual
value when safely available.

Exit status is `0` for `verified` and `proceeding_under_exception`, `2` for
`blocked`, `64` for invalid command invocation, and `70` for an unexpected
internal failure. Standard error is reserved for invocation and internal errors.

`render-index` is a read-only deterministic renderer. It writes only the exact
derived Markdown to standard output and exits `0`, `64`, or `70`. The output is:

```markdown
Architecture decisions do not authorize work. Accepted status does not by itself establish current applicability, and historical records do not override current instructions.

| ADR | Decision status |
| --- | --- |
```

The renderer appends one row per catalog record in numeric ADR order and one
final newline. The ADR cell is the Markdown-escaped title linked to the relative
catalog path without `.md`; the status cell is the exact catalog status. It does
not mutate the index or any Git object.

## Transition authorization input

The UTF-8 JSON object has exactly `version`, `ticket`, `operation`,
`priorRevision`, `candidateRevision`, `changes`, and `approvalRef`. Version is
`1`. Each change has exactly `id` and `actions`; actions are drawn from `add`,
`remove`, `path`, `baseline`, `status`, `domain`, `scopes`, and
`proposed-body`. This file binds the structural comparison. It is not evidence
of human intent, and the checker does not authenticate its author.

An explicitly selected ADR must cover at least one invoked scope. Structural
`verified` means selected bytes and declared applicability are internally valid;
it does not make Proposed or historical applicability governing or establish
semantic compatibility. Only Accepted `current` applicability can supply a
current governing constraint, subject to the invoking role's trusted assignment
and conflict analysis.

## Exception inputs

`--diagnostics` is the entire exact JSON object written by the immediately
preceding blocked snapshot check, not only its diagnostics array. The exception
command recomputes the current check and rejects changed ticket, operation,
revision, selection, scopes, or diagnostics.

`--issue-snapshot` is a fresh, complete, authorized GitHub read normalized as a
version `1` object with exactly `version`, `issue`, `comments`, and
`commentsComplete`. `issue` contains exactly `url`, `state`, and `body`.
Each comment contains exactly `id`, `url`, `updatedAt`, and `body`.
The skill must obtain this snapshot through the authorized GitHub route
immediately before the check and establish complete pagination. File contents
alone cannot prove freshness; the validator checks the binding but cannot
authenticate the external read.

`--trusted-approval` is separate trusted task context. Its version `1` object
contains exactly `version`, `exceptionId`, `repository`, `wikiRepository`,
`issue`, `operation`, `commentId`, `commentUpdatedAt`, `blockSha256`,
`approvalRef`, and `revokedOrResolvedIds`. The checker never constructs this
context from GitHub authorship, association, issue prose, or the exception
record itself.

Expiry is compared with the validator's current UTC wall clock. The caller
cannot provide or override time.

Eligible failure tuples use these exact bindings:

- `ADR_MISSING` relies on the missing catalog record's fixed accepted baseline.
- `ADR_UNCATALOGUED` relies on the exact observed Proposed bytes as informational
  context only.
- `ADR_BLOB_MISMATCH` relies on the exact observed Accepted/Superseded bytes only
  after fixed body and immutable metadata validation succeeds.
- `ADR_SNAPSHOT_STALE` and `ADR_FRESHNESS_UNAVAILABLE` use path
  `ADR-Catalog.json`, the retained inspected `catalogRevision`, and the retained
  catalog blob for both `expectedBlob` and `observedBlob`. Equality proves the
  approved retained identity only, never currentness. The recomputed diagnostic
  separately preserves stale versus unavailable and the remote HEAD when known.

Top-level catalog/index bindings and every ADR actually consumed under an
exception must resolve to the same approved reliance snapshot, except that a
missing accepted ADR resolves through its fixed baseline. A successful freshness
exception reports currentness as `retained-not-current` or `unknown`, never
current.

The exact exception record schema, eligibility rules, limits, and approval
binding come from the fixed accepted contract returned by `read-contract`; its
[rendered Wiki page](https://github.com/joeroberts/release-radar/wiki/Scoped-Development-Exceptions-Contract)
is navigation only.
