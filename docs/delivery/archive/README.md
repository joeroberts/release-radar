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
temporary originals were not deleted. `SHA256SUMS` preserves the accepted original archive checksums. The catalog
identifies each artifact's applicable checksum policy; newer historical plans
and delivery records do not add checksums for mutable working documents.

## Superpowers records preserved September 16

The 14 `superpowers_*.md` files in this directory preserve the original Markdown
from `.superpowers/sdd/<folder>/<filename>` unchanged. The flat name is
`superpowers_<folder>_<filename>`; the original folder is the dated project name.
They are historical, non-authoritative drafts, intermediate status records,
implementation/QA reports, and review patches. Their old instructions, links,
paths, approval claims, and test results describe their original context and do
not authorize current work. Original internal references remain unchanged for
provenance; use the catalog entries below to locate these preserved records.
The existing `sdd/` archive and accepted checksum manifest are unchanged.

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

## MDCP document cutover

The six original artifact IDs survive these path changes. Historical plans
retain their original narrative; the current plan/specification keep their
existing authority. This map records relocation, not execution authorization.

| Prior path | Current path |
| --- | --- |
| `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` | `docs/delivery/archive/2026-08-23-release-radar-mvp.md` |
| `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` | `docs/delivery/archive/2026-08-25-release-radar-remediation.md` |
| `docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md` | `docs/delivery/archive/2026-08-27-codex-plugin-lifecycle.md` |
| `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md` | `docs/delivery/archive/2026-08-29-release-radar-active-phase-selection.md` |
| `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md` | `docs/delivery/plans/2026-08-29-delivery-goals-roadmap-readiness.md` |
| `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md` | `docs/design/2026-08-29-delivery-goals-roadmap-readiness-design.md` |

Closed delivery detail through M6B is preserved in
[the historical progress record](2026-09-02-progress-through-mdcp-m6b.md).
The live progress artifact retains its original ID and path.

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
| acb2bdfe-b052-40bc-aac7-80742791aa50 | [docs/delivery/archive/2026-08-23-release-radar-mvp.md](2026-08-23-release-radar-mvp.md) | document | nonAuthoritative | superseded | none | none |
| b7ad406a-3131-4eaa-8f8b-fbee0fcd26dc | [docs/delivery/archive/2026-08-25-release-radar-remediation.md](2026-08-25-release-radar-remediation.md) | document | nonAuthoritative | superseded | none | none |
| 0ff7a384-fbb1-4ff1-bb0b-fbbd27b466a3 | [docs/delivery/archive/2026-08-27-codex-plugin-lifecycle.md](2026-08-27-codex-plugin-lifecycle.md) | document | nonAuthoritative | archived | none | none |
| 7d88279f-a192-4b4e-83ab-36e144a734dd | [docs/delivery/archive/2026-08-29-release-radar-active-phase-selection.md](2026-08-29-release-radar-active-phase-selection.md) | document | nonAuthoritative | archived | none | none |
| 347a1392-285b-4c82-8b6f-a61832501e54 | [docs/delivery/archive/2026-08-31-progress-through-rr-r10-task-2b.md](2026-08-31-progress-through-rr-r10-task-2b.md) | document | nonAuthoritative | archived | none | none |
| eb5a4f12-727d-4547-bc47-aa3cb9f26c64 | [docs/delivery/archive/2026-09-02-progress-through-mdcp-closeout-and-rr-r10-review.md](2026-09-02-progress-through-mdcp-closeout-and-rr-r10-review.md) | document | nonAuthoritative | archived | none | none |
| d8f875e8-c5ec-486b-9e76-068003c5fa01 | [docs/delivery/archive/2026-09-02-progress-through-mdcp-m6b.md](2026-09-02-progress-through-mdcp-m6b.md) | document | nonAuthoritative | archived | none | none |
| 614cd400-b180-4ace-b1de-38381fc66992 | [docs/delivery/archive/2026-09-02-rr-r10-task-7a-closeout.md](2026-09-02-rr-r10-task-7a-closeout.md) | document | nonAuthoritative | archived | none | none |
| rr-c8-and-baseline-closeout-2026-09-06 | [docs/delivery/archive/2026-09-06-c8-and-baseline-closeout.md](2026-09-06-c8-and-baseline-closeout.md) | document | nonAuthoritative | archived | none | none |
| rr-operating-baseline-closeout-2026-09-06 | [docs/delivery/archive/2026-09-06-operating-baseline-closeout.md](2026-09-06-operating-baseline-closeout.md) | document | nonAuthoritative | archived | none | none |
| rr-c6-delivery-history-2026-09-07 | [docs/delivery/archive/2026-09-07-c6-delivery-history.md](2026-09-07-c6-delivery-history.md) | document | nonAuthoritative | archived | none | none |
| rr-c7-delivery-history-2026-09-07 | [docs/delivery/archive/2026-09-07-c7-delivery-history.md](2026-09-07-c7-delivery-history.md) | document | nonAuthoritative | archived | none | none |
| rr-recovery-through-c4-discoveries-2026-09-07 | [docs/delivery/archive/2026-09-07-recovery-through-c4-and-parallel-discoveries.md](2026-09-07-recovery-through-c4-and-parallel-discoveries.md) | document | nonAuthoritative | archived | none | none |
| rr-recovery-through-c5-2026-09-07 | [docs/delivery/archive/2026-09-07-recovery-through-c5.md](2026-09-07-recovery-through-c5.md) | document | nonAuthoritative | archived | none | none |
| rr-phase3-delivery-history-2026-09-08 | [docs/delivery/archive/2026-09-08-phase3-delivery-history.md](2026-09-08-phase3-delivery-history.md) | document | nonAuthoritative | archived | none | none |
| rr-phase5-shared-history-2026-09-10 | [docs/delivery/archive/2026-09-10-phase5-shared-delivery-history.md](2026-09-10-phase5-shared-delivery-history.md) | document | nonAuthoritative | archived | none | none |
| rr-phase6-delivery-history-2026-09-11 | [docs/delivery/archive/2026-09-11-phase6-delivery-history.md](2026-09-11-phase6-delivery-history.md) | document | nonAuthoritative | archived | none | none |
| 9f08525c-3dbb-487d-9a70-24ebff25443c | [docs/delivery/archive/README.md](README.md) | collectionIndex | nonAuthoritative | active | none | none |
| 31277e5a-3a64-4c1f-bc15-26d6f4a935d4 | [docs/delivery/archive/SHA256SUMS](SHA256SUMS) | checksumManifest | nonAuthoritative | archived | none | none |
| 7083d512-96d6-4cab-b368-19dacc95e146 | [docs/delivery/archive/superpowers&#95;2026-08-27-codex-plugin-lifecycle&#95;task-1-brief.md](superpowers_2026-08-27-codex-plugin-lifecycle_task-1-brief.md) | document | nonAuthoritative | archived | none | none |
| 8eb93f63-de4b-46fd-8ce0-4dc5105f6fab | [docs/delivery/archive/superpowers&#95;2026-08-29-delivery-goals-roadmap-readiness&#95;ledger.md](superpowers_2026-08-29-delivery-goals-roadmap-readiness_ledger.md) | document | nonAuthoritative | archived | none | none |
| 2bfc8d3a-cc0e-4c0d-8aec-550c850f9150 | [docs/delivery/archive/superpowers&#95;2026-08-29-delivery-goals-roadmap-readiness&#95;task-1-plan-excerpt.md](superpowers_2026-08-29-delivery-goals-roadmap-readiness_task-1-plan-excerpt.md) | document | nonAuthoritative | archived | none | none |
| 21d45764-5c45-43f9-8558-9f4caef52d31 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;progress.md](superpowers_2026-08-29-release-radar-active-phase-selection_progress.md) | document | nonAuthoritative | archived | none | none |
| cefe1892-1e54-4c85-9622-c4596a0910ca | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-1-report.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-1-report.md) | document | nonAuthoritative | archived | none | none |
| d2c18c2f-3a8c-47c5-a18b-4f53c38a048c | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-1-review-package.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-1-review-package.md) | document | nonAuthoritative | archived | none | none |
| 4fb1edbe-ae63-4e9a-9576-e07b6d9eac10 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-2-report.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-2-report.md) | document | nonAuthoritative | archived | none | none |
| 54664d1a-baec-411f-ad83-a5e9f0e05964 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-2-review-fix-1-package.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-2-review-fix-1-package.md) | document | nonAuthoritative | archived | none | none |
| ebc51db7-644b-4c49-8ff2-7014567cbab6 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-2-review-package.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-2-review-package.md) | document | nonAuthoritative | archived | none | none |
| a65071c5-cf5e-462f-b652-c2a47823f4b0 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-2-security-fix-package.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-2-security-fix-package.md) | document | nonAuthoritative | archived | none | none |
| 4916dbc4-f1c1-4062-9311-b7f558431bea | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-3-report.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-3-report.md) | document | nonAuthoritative | archived | none | none |
| d03f7510-32c3-4efe-8d01-4f74de43b785 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-3-test-host-isolation-correction-report.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-3-test-host-isolation-correction-report.md) | document | nonAuthoritative | archived | none | none |
| 014e1944-481f-4ad3-a3fe-d125f6280661 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-3-test-host-isolation-correction-review-package.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-3-test-host-isolation-correction-review-package.md) | document | nonAuthoritative | archived | none | none |
| 110f1f5f-b5a8-4531-a6f3-ba9b6476a7c2 | [docs/delivery/archive/superpowers&#95;2026-08-29-release-radar-active-phase-selection&#95;task-3-test-host-isolation-qa-report.md](superpowers_2026-08-29-release-radar-active-phase-selection_task-3-test-host-isolation-qa-report.md) | document | nonAuthoritative | archived | none | none |

### Children

- [delivery.archive.sdd](sdd/README.md) — indexed; Historical SDD delivery packages
- [delivery.archive.temporary-artifacts](temporary-artifacts/README.md) — indexed; Canonical copies of historical temporary delivery material

<!-- release-radar-docs:end -->
