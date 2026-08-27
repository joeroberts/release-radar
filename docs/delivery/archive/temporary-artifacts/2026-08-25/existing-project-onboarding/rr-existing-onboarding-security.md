# Security/Privacy Gate — Existing-Project Onboarding

## Decisions

| Work item | Gate |
|---|---|
| **Attach Folder to Existing Project** | **GO — Security/Privacy**. Implementation remains release-closed until RR-R7 completes or TPM/Delivery Management explicitly reprioritizes it. |
| **Portable archive-contract definition** | **GO — definition work only**. No importer or UI implementation is authorized by this decision. |
| **Portable importer** | **NO-GO** until the versioned contract, producer provenance, device-local exclusions, collision policy, and audit treatment are approved. |
| **Import Existing Release Radar Project** | **NO-GO** until the portable importer passes independent security/privacy and QA verification. |

## Required

1. **Preserve two explicit workflows**

   - `Attach Folder to Existing Project`
   - `Import Existing Release Radar Project`

   Attach must select an existing project first, name it in confirmation, and call `associateFirstProjectRoot` directly. It must not call onboarding `inspect`, `prepare`, `finish`, the Rekon importer, or any Markdown scanner.

2. **Attach authorization boundary**

   The existing core is acceptable: it canonicalizes and resolves symlinks, requires a directory, rejects any existing root/bookmark, rejects globally owned canonical roots, validates a fresh security-scoped bookmark, verifies active scope and canonical-root equality, and writes through one transaction ([ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351), [ProjectBookmarkStore.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift:60)).

   Required acceptance evidence:

   - Canonical and symlink-equivalent ownership conflicts fail without mutation.
   - Root-only, bookmark-only, and fully associated targets fail closed.
   - Bookmark resolution, stale state, root mismatch, and denied scope create no root, bookmark, or association audit.
   - Scope starts/stops remain balanced.
   - Repeat submission cannot add a second root, bookmark, audit, or delivery record.
   - A populated delivery graph and unrelated-project/global state remain value-equivalent; only one root, one bookmark, and one association audit may be added.

3. **SQLite atomicity and audit privacy**

   Attach and future portable import must use one store-owned `BEGIN IMMEDIATE` transaction, with the automatic audit committed or rolled back with all data ([DeliveryStore.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Store/DeliveryStore.swift:116)). Global root uniqueness remains enforced by the database ([StoreMigrations.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Store/StoreMigrations.swift:551)).

   The Attach audit must remain exactly one project-scoped owner event with the fixed reason `Associate first project folder authorization`. It must contain no absolute path, bookmark bytes, project contents, goal/reason text, or other delivery data. Add an association-specific privacy assertion; current coverage proves the bounded mutation but not preservation of a complete populated graph or path-free association auditing ([OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:445)).

4. **Portable archive contract**

   Before importer implementation, the contract must define:

   - One exact container, manifest location, schema version, authoritative producer, stable source-project identity, and concrete entry/byte/record limits.
   - Strict rejection of unsupported versions, missing sections, duplicate keys or identities, invalid references, cycles, truncation, and ambiguous records. Portable restoration must not degrade invalid data into partial “Needs Review” imports.
   - Canonical relative entry names only. Reject absolute paths, `..`, NULs, duplicate or case/Unicode-colliding names, symlinks, hardlinks, special files, nested archives, and compression/resource exhaustion.
   - Descriptor-anchored reads or an equivalent no-follow implementation. If extraction is necessary, use a unique app-private temporary directory, never the selected project root.
   - A digest over the exact previewed bytes; confirmation must import those same immutable bytes or fail if they changed.
   - Source-byte preservation and no Markdown inference. Arbitrary Markdown and current Rekon `dashboard-status.json` must be explicitly rejected as portable-project sources.

5. **Device-local fields**

   The contract must explicitly classify every field. At minimum:

   | Data | Required treatment |
   |---|---|
   | Root paths and bookmark bytes | Never imported; create a fresh bookmark for the owner-selected destination root. |
   | Keychain credentials | Never exported or imported. |
   | `agent_command_requests` replay state and global alert rules | Never imported. |
   | `first_dashboard_opened` | Reset to false. |
   | Notification occurrences, queued/attempt state, receipts and provider failures | Never reactivate or dispatch; omit unless an approved inert historical representation exists. |
   | Absolute evidence paths | Never retained; use contract-defined relative paths rebased and revalidated under the destination root. |
   | Codex thread/goal identities and freshness | Omit or import only as explicitly marked inert/stale history; never claim live or verified linkage. |
   | Audit history | Either exclude it or use a separately approved, provenance-marked store-owned history contract. Never insert imported records as current trusted app audits or weaken transaction callback restrictions. |

   Every successful portable import creates only one current, bounded import audit, without archive paths or imported content.

6. **Portable importer and duplicate prevention**

   After contract approval, the importer must:

   - Be separate from `RekonArtifactImporter`; the latter is an intentionally partial seed importer ([DeliveryArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9)).
   - Create the project, deterministic complete ID mapping, canonical unowned destination root, fresh bookmark, graph, provenance, and one audit in a single transaction.
   - Recheck root ownership, digest, identity collisions, foreign keys, and cycles at commit time.
   - Roll back the project, root, bookmark, graph, provenance, and audit on any failure.
   - Define retry/idempotency behavior using stable archive identity so the same archive cannot create duplicate delivery records or a second project accidentally.
   - Produce no notification occurrence, outbox attempt, bridge request, onboarding marker, or external service call.

7. **UI and post-commit truth**

   Cancellation, Escape, folder/archive chooser cancellation, and window close before confirmation perform zero durable writes. Confirmed transactions must not be interactively dismissible while their result is unknown. After commit, refresh failure must say the import or attachment was saved and must not be retried.

8. **Isolated live verification**

   Because the prior normal-bundle run touched owner data ([progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:284)), all live acceptance must use:

   - A never-before-used alternate bundle/container.
   - Debug capture suppression and an isolated temporary/alternate-container database.
   - No owner bundle, owner database, owner folder authorization, Keychain read, bridge startup, notification dispatch, or provider network request.
   - Pre/post evidence that owner-container metadata was unchanged.
   - Accessibility and screenshots compared with `onboarding_state.png`, including its explicit history-preserving recovery language.

## Optional

- A dedicated file extension/UTType for the portable archive.
- Displaying a shortened archive digest or exporter version in confirmation for owner troubleshooting.

Neither blocks the gate if the underlying strict recognition and digest controls exist.

## Out of scope

- Expanding the Rekon seed importer into complete-project restoration.
- Importing SQLite databases, repository Markdown, ledgers, task briefs, or handoffs as delivery authority.
- Cloud/shared import, archive encryption or signing, multiple roots/worktrees, export UI, notification delivery, owner-data recovery, or new credentials/entitlements.
- Any competing delivery report or ledger. The eventual durable gate record belongs only in [docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:1).