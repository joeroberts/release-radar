# SQLite-23 Post-RED QA/Test Review

**Decision:** GO for implementation to resume after Delivery releases a fresh sole Implementer.

**Required findings:** 0

## Scope reviewed

This review is limited to the post-RED correction and the owner-required
populated migrated-schema fixture/preservation addendum. It does not approve
the eventual implementation, diagnostics, packaging, installation, or owner
validation.

Reviewed inputs:

- `AGENTS.md`
- `/tmp/release-radar-sqlite23-repair-brief.md`
- `/tmp/release-radar-sqlite23-implementer-report.md`
- `docs/delivery/progress.md`, especially “Repair-plan ruling after first RED”
- Retained RED result bundle `/tmp/release-radar-sqlite23-red-verified.xcresult`

## Evidence assessment

The combined observations constitute a valid deterministic RED for this
repair:

1. The retained XCTest result independently confirms that the real
   `FolderProjectOnboarding.prepare` callback failed at the SQLite boundary
   with primary code `SQLITE_AUTH` (23). The callback path uses the production
   project upsert and the legacy compatibility triggers.
2. The independent standalone synthetic diagnostic captured the causal
   authorizer tuple `(SQLITE_READ, audit_events, project_id)` and the exact
   owner-visible authorization text. Its negative control without the legacy
   triggers prepared and executed the same upsert.
3. The human-readable SQLite error message is not a stable cross-wrapper
   assertion: the real wrapper exposed `not authorized`, while the direct
   diagnostic exposed `access to audit_events.project_id is prohibited`. Both
   are consistent with the same primary authorization failure. Binding the
   regression to code 23, the actual callback/upsert/legacy-trigger path, and
   the independently captured tuple is deterministic and does not dilute the
   owner-reported symptom.

This distinction is appropriate because a requirement for byte-identical
`sqlite3_errmsg` text in every wrapper would reject the demonstrated production
path for a presentation difference unrelated to the authorizer decision.

## Populated fixture and preservation contract

The amended brief is adequate and satisfies the owner addendum. Before the
legacy objects are installed, the test must use the current `DeliveryStore` to
create a synthetic version-9 database containing an unrelated project, its
active phase/relationship, an ordinary ticket or equivalent child, and a
project-scoped store-owned audit. It then snapshots exact existing row values,
relationships, and relevant counts; reopens through the recognized legacy
shape; and runs the actual `inspect`/`prepare` flow.

The specified post-fix assertions require field-for-field and
relationship-for-relationship preservation of that pre-existing state. The
only permitted delta is the exact new onboarding project/root/bookmark/pending
marker plus one prepare audit. Existing requirements additionally cover the
repository sentinel/listing, relaunch, bookmark-scope balance, foreign-key
integrity, and no automatic phase/command/notification actions. This is
production-shaped evidence without copying owner data.

The current on-disk RED test predates the addendum and starts empty; it cannot
serve as final migrated-state evidence. The amended brief expressly requires
the released Implementer to revise it before any production authorizer change.
That sequencing is sufficient and is not a plan blocker.

## Findings

### Required

None.

### Optional

None.

### Out of scope

- Requiring identical human-readable SQLite error wording from every wrapper
  after the standalone diagnostic has already captured the owner-visible text
  and causal authorizer tuple.
- Requiring owner database content or runtime access to construct the fixture.
- Reviewing the eventual authorizer implementation, diagnostics, audit-mutation
  matrix, build/install script, Release artifact, or owner validation in this
  preimplementation ruling.

## Release-gate conclusion

QA/test approves the amended RED definition and populated-fixture contract.
Implementation may resume only under the existing gate: Delivery must release
a fresh sole Implementer, who first revises and records the populated RED
fixture/result before changing production code. All required independent
post-implementation reviews and the owner validation terminal gate remain in
force.
