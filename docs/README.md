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

<!-- release-radar-docs:end -->
