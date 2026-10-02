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

python3 .agents/skills/adr-management/scripts/adr_checker.py exception \
  --repository WIKI_CLONE --wiki-repository WIKI_URL --revision COMMIT \
  --ticket ISSUE_URL --operation NAME --scope SCOPE [--scope SCOPE ...] \
  --diagnostics FILE --issue-snapshot FILE --trusted-approval FILE \
  --now RFC3339_UTC
```

`snapshot`, `transition`, and `exception` resolve the canonical remote HEAD and
read named commits using Git object commands. They require the repository's
`origin` URL to match `--wiki-repository`. `snapshot` requires `--revision` to
equal that remote HEAD. `transition` instead requires `--prior-revision` to equal
the remote HEAD; its candidate may be an unpublished local descendant so it can
be validated before publication. The Release Radar catalog additionally requires
the exact canonical identity
`https://github.com/joeroberts/release-radar.wiki.git`.

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

The exact exception record schema, eligibility rules, limits, and approval
binding remain canonical in the
[Scoped Development Exceptions contract](https://github.com/joeroberts/release-radar/wiki/Scoped-Development-Exceptions-Contract).
