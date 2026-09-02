# Tracked task briefs

This directory contains the durable, tracked copies of Release Radar task
briefs that were accepted or cited as controlling during delivery.

- `docs/delivery/progress.md` remains the sole authority for current status,
  dependency gates, sequencing, and task eligibility.
- A brief records the reviewed scope for a task; its presence does not mean the
  task is currently open.
- Completed or superseded briefs remain here as historical delivery contracts.
- New controlling briefs must be placed here before implementation begins and
  must not be cited from `/tmp`, `.superpowers/sdd/`, or another ignored path.
- `SHA256SUMS` preserves the accepted historical brief checksums. New mutable
  briefs are catalogued without checksums under ADR-007.

<!-- release-radar-docs:v1:start -->

## Collection: delivery.task-briefs

- Path: [docs/delivery/task-briefs](.)
- Purpose: Reviewed task scopes; current progress determines the open task
- Allowed contents: Accepted pre-M1 checksum manifest; Dated task-brief collections
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [a8065da2-31dc-45b8-a8a1-f711ae82bd5a](README.md)
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| a8065da2-31dc-45b8-a8a1-f711ae82bd5a | [docs/delivery/task-briefs/README.md](README.md) | collectionIndex | supporting | active | none | none |
| a5c1293d-7b06-4bb9-acd6-6e9f1d0a35c4 | [docs/delivery/task-briefs/SHA256SUMS](SHA256SUMS) | checksumManifest | nonAuthoritative | completed | none | none |

### Children

- [delivery.task-briefs.2026-08-23-release-radar-mvp](2026-08-23-release-radar-mvp) — leaf; Task scopes for 2026-08-23-release-radar-mvp; current progress determines eligibility
- [delivery.task-briefs.2026-08-25-release-radar-remediation](2026-08-25-release-radar-remediation) — leaf; Task scopes for 2026-08-25-release-radar-remediation; current progress determines eligibility
- [delivery.task-briefs.2026-08-27-codex-plugin-lifecycle](2026-08-27-codex-plugin-lifecycle) — leaf; Task scopes for 2026-08-27-codex-plugin-lifecycle; current progress determines eligibility
- [delivery.task-briefs.2026-08-28-codex-repository-handoff-correction](2026-08-28-codex-repository-handoff-correction) — leaf; Task scopes for 2026-08-28-codex-repository-handoff-correction; current progress determines eligibility
- [delivery.task-briefs.2026-08-29-delivery-goals-roadmap-readiness](2026-08-29-delivery-goals-roadmap-readiness) — leaf; Task scopes for 2026-08-29-delivery-goals-roadmap-readiness; current progress determines eligibility
- [delivery.task-briefs.2026-08-29-release-radar-active-phase-selection](2026-08-29-release-radar-active-phase-selection) — leaf; Task scopes for 2026-08-29-release-radar-active-phase-selection; current progress determines eligibility
- [delivery.task-briefs.2026-09-01-managed-repository-documentation-contract](2026-09-01-managed-repository-documentation-contract) — leaf; Task scopes for 2026-09-01-managed-repository-documentation-contract; current progress determines eligibility

## Leaf collection: delivery.task-briefs.2026-08-23-release-radar-mvp

- Path: [docs/delivery/task-briefs/2026-08-23-release-radar-mvp](2026-08-23-release-radar-mvp)
- Purpose: Task scopes for 2026-08-23-release-radar-mvp; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| f020c938-e160-4aa6-8506-6b4ec74a0de0 | [docs/delivery/task-briefs/2026-08-23-release-radar-mvp/task-1-brief.md](2026-08-23-release-radar-mvp/task-1-brief.md) | document | nonAuthoritative | completed | none | none |
| f340454f-d73e-4b53-af27-d268640e00d0 | [docs/delivery/task-briefs/2026-08-23-release-radar-mvp/task-2-brief.md](2026-08-23-release-radar-mvp/task-2-brief.md) | document | nonAuthoritative | completed | none | none |
| 40acd42a-78ae-4eee-aa6d-01e2dba08e92 | [docs/delivery/task-briefs/2026-08-23-release-radar-mvp/task-3-brief.md](2026-08-23-release-radar-mvp/task-3-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-08-25-release-radar-remediation

- Path: [docs/delivery/task-briefs/2026-08-25-release-radar-remediation](2026-08-25-release-radar-remediation)
- Purpose: Task scopes for 2026-08-25-release-radar-remediation; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| f46d5ba0-7300-4c67-96a9-ced30c049b38 | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-1-brief.md](2026-08-25-release-radar-remediation/task-1-brief.md) | document | nonAuthoritative | completed | none | none |
| 44d69b23-e8ed-4b69-b282-ab6da4009c7a | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-2-brief.md](2026-08-25-release-radar-remediation/task-2-brief.md) | document | nonAuthoritative | completed | none | none |
| cedf858c-22fb-4fc4-9f10-671a049b920b | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-3-brief.md](2026-08-25-release-radar-remediation/task-3-brief.md) | document | nonAuthoritative | completed | none | none |
| a4b240e1-33b6-4d81-88c0-eee719366721 | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-4-brief.md](2026-08-25-release-radar-remediation/task-4-brief.md) | document | nonAuthoritative | completed | none | none |
| f2ff69df-b6ec-433c-a6f8-499d3b7d240d | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-5-brief.md](2026-08-25-release-radar-remediation/task-5-brief.md) | document | nonAuthoritative | completed | none | none |
| 24a28665-5b56-409f-b829-4350c0887371 | [docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-6-brief.md](2026-08-25-release-radar-remediation/task-6-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-08-27-codex-plugin-lifecycle

- Path: [docs/delivery/task-briefs/2026-08-27-codex-plugin-lifecycle](2026-08-27-codex-plugin-lifecycle)
- Purpose: Task scopes for 2026-08-27-codex-plugin-lifecycle; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 3fb8fea0-9ffa-4d47-abcb-5a5c26ae5a4b | [docs/delivery/task-briefs/2026-08-27-codex-plugin-lifecycle/task-1-brief.md](2026-08-27-codex-plugin-lifecycle/task-1-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-08-28-codex-repository-handoff-correction

- Path: [docs/delivery/task-briefs/2026-08-28-codex-repository-handoff-correction](2026-08-28-codex-repository-handoff-correction)
- Purpose: Task scopes for 2026-08-28-codex-repository-handoff-correction; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| e366d34f-4b76-4458-bed3-25bd93400d4b | [docs/delivery/task-briefs/2026-08-28-codex-repository-handoff-correction/task-1-brief.md](2026-08-28-codex-repository-handoff-correction/task-1-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-08-29-delivery-goals-roadmap-readiness

- Path: [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness](2026-08-29-delivery-goals-roadmap-readiness)
- Purpose: Task scopes for 2026-08-29-delivery-goals-roadmap-readiness; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| a1e930aa-1ab0-47f3-a77f-c1986686b7e0 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-10-phase-browsing-delivery-goals-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-10-phase-browsing-delivery-goals-brief.md) | document | nonAuthoritative | completed | none | none |
| d97170ea-7811-4aba-b068-bd69d6ee0ea1 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11a-integration-staged-candidate-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-11a-integration-staged-candidate-brief.md) | document | controlling &#40;delivery.rr-r10-task-11a&#41; | active | none | none |
| 362c407f-7d7b-488b-9204-91c8b0103265 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md) | document | nonAuthoritative | completed | none | none |
| 8cec7739-107d-4180-94aa-c9956515226d | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md) | document | nonAuthoritative | completed | none | none |
| 2bf0c300-f961-48a0-8351-4278bf27397f | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md) | document | nonAuthoritative | completed | none | none |
| 856bfbb7-9835-4435-839b-4dc3290cacb2 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md) | document | nonAuthoritative | completed | none | none |
| d216d1ba-5c5f-4e68-8ee8-8fe74041b07a | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md) | document | nonAuthoritative | completed | none | none |
| 4a630e58-ff66-43cb-9c54-89dd9d6c13c8 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-3-ticket-task-planning-policy-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-3-ticket-task-planning-policy-brief.md) | document | nonAuthoritative | completed | none | none |
| 0d74594e-6d13-48dc-b634-f1f17cf84383 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4a-guard-every-accepted-path-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-4a-guard-every-accepted-path-brief.md) | document | nonAuthoritative | completed | none | none |
| edf26376-b869-41d0-99de-5d848a51dd9a | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4b-audited-ticket-task-commands-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-4b-audited-ticket-task-commands-brief.md) | document | nonAuthoritative | completed | none | none |
| 709a940d-b43d-484c-859d-8c88c0592f27 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-5-ticket-task-presentation-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-5-ticket-task-presentation-brief.md) | document | nonAuthoritative | completed | none | none |
| 9bb82f9f-8b26-45ff-b2da-f4a3a19f670c | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-6-delivery-planning-policy-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-6-delivery-planning-policy-brief.md) | document | nonAuthoritative | completed | none | none |
| bf4b1c0f-ec77-4641-b23d-efdfc5cbe467 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-7-ticket-writer-policy-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-7-ticket-writer-policy-brief.md) | document | nonAuthoritative | completed | none | none |
| bc74c88a-cc63-4deb-8b2b-63ed254a476f | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-7a-install-bootstrap-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-7a-install-bootstrap-brief.md) | document | nonAuthoritative | completed | none | none |
| 7856796b-eb43-47cd-b897-20234cd94131 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-7a-install-bootstrap-runbook.md](2026-08-29-delivery-goals-roadmap-readiness/task-7a-install-bootstrap-runbook.md) | document | supporting | active | none | none |
| dda2b5e7-4a6a-4557-ba4c-8685bb3f76da | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-8-audited-delivery-goal-commands-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-8-audited-delivery-goal-commands-brief.md) | document | nonAuthoritative | completed | none | none |
| f8d9dbb3-0bfe-4e3c-a7a1-b481b3982ce9 | [docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-9-delivery-projections-brief.md](2026-08-29-delivery-goals-roadmap-readiness/task-9-delivery-projections-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-08-29-release-radar-active-phase-selection

- Path: [docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection](2026-08-29-release-radar-active-phase-selection)
- Purpose: Task scopes for 2026-08-29-release-radar-active-phase-selection; current progress determines eligibility
- Allowed contents: Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| ae5da424-6f01-4cf4-b1ba-70139de6efb4 | [docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-1-brief.md](2026-08-29-release-radar-active-phase-selection/task-1-brief.md) | document | nonAuthoritative | completed | none | none |
| 48bf4113-6967-4c9f-a64a-4e9146774afe | [docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-2-brief.md](2026-08-29-release-radar-active-phase-selection/task-2-brief.md) | document | nonAuthoritative | completed | none | none |
| 1f44ebad-e24c-4a83-8fa3-a21255eefc47 | [docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md](2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.task-briefs.2026-09-01-managed-repository-documentation-contract

- Path: [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract](2026-09-01-managed-repository-documentation-contract)
- Purpose: Task scopes for 2026-09-01-managed-repository-documentation-contract; current progress determines eligibility
- Allowed contents: Activation runbooks; Reviewed task briefs
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [011f16aa-fb30-458e-947b-56a8097415fb](2026-09-01-managed-repository-documentation-contract/m4-stage-repository-catalog-brief.md)
- Archive destination: [delivery.archive](../archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 82355cfa-0ee1-4c00-bd41-52b22644e3f4 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m2a-catalog-contract-validator-brief.md](2026-09-01-managed-repository-documentation-contract/m2a-catalog-contract-validator-brief.md) | document | nonAuthoritative | completed | none | none |
| fcee4578-9eb4-4788-9e00-fe5c3e2ad0c1 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m2b-deterministic-index-tool-brief.md](2026-09-01-managed-repository-documentation-contract/m2b-deterministic-index-tool-brief.md) | document | nonAuthoritative | completed | none | none |
| 953f31c6-4844-4b6a-ab5d-051a70dd9ed0 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m2c-central-path-contract-v1-preview-brief.md](2026-09-01-managed-repository-documentation-contract/m2c-central-path-contract-v1-preview-brief.md) | document | nonAuthoritative | completed | none | none |
| ae719f13-6dca-48b1-972d-c7d725dd8b50 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m3a-managed-evidence-identity-brief.md](2026-09-01-managed-repository-documentation-contract/m3a-managed-evidence-identity-brief.md) | document | nonAuthoritative | completed | none | none |
| df35073f-6a52-4535-9add-bb720826eac7 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m3a0-schema-v12-fixture-brief.md](2026-09-01-managed-repository-documentation-contract/m3a0-schema-v12-fixture-brief.md) | document | nonAuthoritative | completed | none | none |
| 6003a8f1-8851-45f4-953f-d2655ca377fd | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m3b-evidence-inventory-reconciliation-brief.md](2026-09-01-managed-repository-documentation-contract/m3b-evidence-inventory-reconciliation-brief.md) | document | nonAuthoritative | completed | none | none |
| fcb88ba6-7169-45fb-b80a-849d5616f126 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m3c-readback-root-relocation-brief.md](2026-09-01-managed-repository-documentation-contract/m3c-readback-root-relocation-brief.md) | document | nonAuthoritative | completed | none | none |
| 011f16aa-fb30-458e-947b-56a8097415fb | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m4-stage-repository-catalog-brief.md](2026-09-01-managed-repository-documentation-contract/m4-stage-repository-catalog-brief.md) | document | nonAuthoritative | completed | none | none |
| c44ceed1-073d-455b-bb79-fe345f455a1f | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m5-guidance-v2-compatibility-brief.md](2026-09-01-managed-repository-documentation-contract/m5-guidance-v2-compatibility-brief.md) | document | nonAuthoritative | completed | none | none |
| e47faa43-b783-46de-931f-cc98456224fd | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-inventory-brief.md](2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-inventory-brief.md) | document | nonAuthoritative | completed | none | none |
| bdb0f78b-3c1d-4ce2-8272-27cc5bf88ddd | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md](2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md) | document | supporting | active | none | none |
| 34b9a03b-8249-4468-ac45-bc916038fc47 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m6b-adopt-managed-evidence-brief.md](2026-09-01-managed-repository-documentation-contract/m6b-adopt-managed-evidence-brief.md) | document | nonAuthoritative | completed | none | none |
| c1b4b005-b1e4-452f-bfa2-9099999eb7e1 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m7-catalog-driven-cutover-brief.md](2026-09-01-managed-repository-documentation-contract/m7-catalog-driven-cutover-brief.md) | document | nonAuthoritative | completed | none | none |
| 49eedb35-c8d8-420e-9212-2121b30950d2 | [docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/m8-runtime-acceptance-closeout-brief.md](2026-09-01-managed-repository-documentation-contract/m8-runtime-acceptance-closeout-brief.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
