# Release Radar documentation

<!-- release-radar-docs:v1:start -->

## Collection: docs

- Path: [docs](.)
- Purpose: Release Radar documentation, current authority, and retained history
- Allowed contents: Architecture, design, brand, and delivery collections; Catalog and navigation indexes
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [c48466fb-a4fd-4f9e-96bf-967dfa173216](README.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| c48466fb-a4fd-4f9e-96bf-967dfa173216 | [docs/README.md](README.md) | collectionIndex | supporting | active | none | none |

### Children

- [architecture](architecture) — leaf; Accepted architecture and delivery-policy decisions
- [brand](brand/README.md) — indexed; Approved V1 brand direction and retained design references
- [delivery](delivery/README.md) — indexed; Current delivery status and durable task/evidence history
- [design](design/README.md) — indexed; Accepted product contracts and clearly classified proposals
- [superpowers](superpowers) — leaf; Existing plans/specification transition; root-index enumeration only until M7

## Leaf collection: architecture

- Path: [docs/architecture](architecture)
- Purpose: Accepted architecture and delivery-policy decisions
- Allowed contents: Architecture decision records
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [fd278d0d-b43f-4145-9033-2906f32a6ab8](architecture/ADR-001-release-radar-boundaries.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| fd278d0d-b43f-4145-9033-2906f32a6ab8 | [docs/architecture/ADR-001-release-radar-boundaries.md](architecture/ADR-001-release-radar-boundaries.md) | document | controlling &#40;architecture.boundaries&#41; | active | none | none |
| de35fa8c-3615-4b7f-a028-100aaadaeaf8 | [docs/architecture/ADR-002-codex-plugin-lifecycle.md](architecture/ADR-002-codex-plugin-lifecycle.md) | document | controlling &#40;architecture.codex-plugin-lifecycle&#41; | active | none | none |
| f7cd9af5-0cd1-4707-b05e-007222e0ca8a | [docs/architecture/ADR-003-active-phase-selection.md](architecture/ADR-003-active-phase-selection.md) | document | controlling &#40;architecture.active-phase-selection&#41; | active | none | none |
| 6369c974-23ac-467b-90b7-0c0d0ad426fd | [docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md](architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md) | document | controlling &#40;architecture.delivery-goals-readiness&#41; | active | none | none |
| 9c1cf54c-99cf-4348-af72-1aedc07deb02 | [docs/architecture/ADR-005-ticket-task-work-plans.md](architecture/ADR-005-ticket-task-work-plans.md) | document | controlling &#40;architecture.ticket-tasks&#41; | active | none | none |
| 874c6a9a-f7e9-444e-b38d-c32ceb18a536 | [docs/architecture/ADR-006-managed-repository-documentation-contract.md](architecture/ADR-006-managed-repository-documentation-contract.md) | document | controlling &#40;architecture.managed-documentation&#41; | active | none | none |
| a3918ee6-cc82-40f2-ae84-2d59571b2020 | [docs/architecture/ADR-007-proportional-delivery-validation.md](architecture/ADR-007-proportional-delivery-validation.md) | document | controlling &#40;delivery.validation-policy&#41; | active | none | none |

### Children

Leaf: no child collections.

## Leaf collection: superpowers

- Path: [docs/superpowers](superpowers)
- Purpose: Existing plans/specification transition; root-index enumeration only until M7
- Allowed contents: Existing plans and specs collections
- Prohibited contents: In-subtree generated indexes; New content; Owner data and credentials; Temporary build output
- First read: none
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |

No artifacts.

### Children

- [superpowers.plans](superpowers/plans) — leaf; Existing implementation plans retained in place until M7
- [superpowers.specs](superpowers/specs) — leaf; Existing Delivery Goals specification retained in place until M7

## Leaf collection: superpowers.plans

- Path: [docs/superpowers/plans](superpowers/plans)
- Purpose: Existing implementation plans retained in place until M7
- Allowed contents: Existing five implementation plans
- Prohibited contents: In-subtree generated indexes; New content; Owner data and credentials; Temporary build output
- First read: [cd044b85-6519-4330-ae3c-dc0d9c20a65e](superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md)
- Archive destination: [delivery.archive](delivery/archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| acb2bdfe-b052-40bc-aac7-80742791aa50 | [docs/superpowers/plans/2026-08-23-release-radar-mvp.md](superpowers/plans/2026-08-23-release-radar-mvp.md) | document | nonAuthoritative | superseded | none | none |
| b7ad406a-3131-4eaa-8f8b-fbee0fcd26dc | [docs/superpowers/plans/2026-08-25-release-radar-remediation.md](superpowers/plans/2026-08-25-release-radar-remediation.md) | document | nonAuthoritative | superseded | none | none |
| 0ff7a384-fbb1-4ff1-bb0b-fbbd27b466a3 | [docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md](superpowers/plans/2026-08-27-codex-plugin-lifecycle.md) | document | nonAuthoritative | completed | none | none |
| cd044b85-6519-4330-ae3c-dc0d9c20a65e | [docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md](superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md) | document | controlling &#40;delivery.rr-r10-implementation&#41; | active | none | none |
| 7d88279f-a192-4b4e-83ab-36e144a734dd | [docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md](superpowers/plans/2026-08-29-release-radar-active-phase-selection.md) | document | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: superpowers.specs

- Path: [docs/superpowers/specs](superpowers/specs)
- Purpose: Existing Delivery Goals specification retained in place until M7
- Allowed contents: Existing Delivery Goals and readiness specification
- Prohibited contents: In-subtree generated indexes; New content; Owner data and credentials; Temporary build output
- First read: [eeb25b5c-efbd-4669-8ead-43f0a6fbfbb7](superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md)
- Archive destination: [delivery.archive](delivery/archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| eeb25b5c-efbd-4669-8ead-43f0a6fbfbb7 | [docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md](superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md) | document | controlling &#40;product.delivery-goals-readiness&#41; | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
