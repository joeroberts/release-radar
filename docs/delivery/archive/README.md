# Delivery archive

This directory preserves human-authored Release Radar planning drafts, role
reports, review packages, execution records, and superseded material for
archaeological use.

Everything below this directory is historical and non-authoritative. Archive
content may contain obsolete status, unchecked steps, pre-review findings,
superseded decisions, and old path references. Do not use it to reopen work or
determine task eligibility. `docs/delivery/progress.md` is the sole authority
for current delivery status and sequencing.

The archive deliberately preserves the original file contents. Files moved
from `.superpowers/sdd/` were relocated without editorial rewriting. Files
copied from `/tmp` were byte-compared with their sources after copying; their
temporary originals were not deleted. `SHA256SUMS` records checksums for every
preserved artifact below this directory, excluding this README and the checksum
file itself.

## Layout

- `sdd/`: former ignored SDD briefs, reports, review packages, and local
  progress records. Controlling briefs were separated into
  `docs/delivery/task-briefs/`.
- `temporary-artifacts/2026-08-25/project-planning-ux/`: all five saved UX
  proposal revisions, including the exact v5 source used for the durable
  proposed design document.
- `temporary-artifacts/2026-08-25/initialize-project-tracking/`: Task 7A and
  7B implementer reports.
- `temporary-artifacts/2026-08-25/sqlite23-repair/`: repair brief, independent
  reviews, review packages, owner-validation decision, packaging authorization,
  and packaging evidence.
- `temporary-artifacts/2026-08-25/existing-project-onboarding/`: planning,
  architecture, TPM, QA, security, code-review, and delivery records.

<!-- release-radar-docs:v1:start -->

## Collection: delivery.archive

- Path: [docs/delivery/archive](.)
- Purpose: Historical delivery records; never current task eligibility
- Allowed contents: Accepted checksum manifest; Archive navigation; Preserved historical records
- Prohibited contents: Current execution authority; Owner data and credentials; Temporary build output
- First read: [9f08525c-3dbb-487d-9a70-24ebff25443c](README.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 347a1392-285b-4c82-8b6f-a61832501e54 | [docs/delivery/archive/2026-08-31-progress-through-rr-r10-task-2b.md](2026-08-31-progress-through-rr-r10-task-2b.md) | document | nonAuthoritative | archived | none | none |
| 9f08525c-3dbb-487d-9a70-24ebff25443c | [docs/delivery/archive/README.md](README.md) | collectionIndex | nonAuthoritative | active | none | none |
| 31277e5a-3a64-4c1f-bc15-26d6f4a935d4 | [docs/delivery/archive/SHA256SUMS](SHA256SUMS) | checksumManifest | nonAuthoritative | archived | none | none |

### Children

- [delivery.archive.sdd](sdd/README.md) — indexed; Historical SDD delivery packages
- [delivery.archive.temporary-artifacts](temporary-artifacts/README.md) — indexed; Canonical copies of historical temporary delivery material

<!-- release-radar-docs:end -->
