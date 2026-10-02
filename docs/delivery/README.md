# Delivery documentation

[Repository plans](plans/) retain the supporting implementation plans catalogued
here. A current plan may instead live in the Wiki when its task route identifies
that page. Plans reference the canonical
[Product Specifications](https://github.com/joeroberts/release-radar/wiki/Product-Specifications)
for behavior and contracts; they do not grant authority. Current work, status
and results remain in GitHub and the short [progress snapshot](progress.md).

<!-- release-radar-docs:v1:start -->

## Collection: delivery

- Path: [docs/delivery](.)
- Purpose: Current delivery status and durable task/evidence history
- Allowed contents: Current progress ledger; Historical archive; Implementation plans; Task briefs; Verification evidence
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [450e84de-703b-4dcd-ad1a-7fddfee0d1d9](progress.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 36ea9572-06fb-4faf-b999-f8ad4fd701c2 | [docs/delivery/README.md](README.md) | collectionIndex | supporting | active | none | none |
| 450e84de-703b-4dcd-ad1a-7fddfee0d1d9 | [docs/delivery/progress.md](progress.md) | document | controlling &#40;delivery.current-state&#41; | active | none | none |

### Children

- [delivery.evidence](evidence) — leaf; Durable verification evidence from delivered work
- [delivery.plans](plans) — leaf; Delivery scope, dependencies, sequencing and rollout gates; historical plans are non-authoritative
- [delivery.task-briefs](task-briefs/README.md) — indexed; Active task scopes; GitHub owns current work and results

## Leaf collection: delivery.evidence

- Path: [docs/delivery/evidence](evidence)
- Purpose: Durable verification evidence from delivered work
- Allowed contents: Immutable test evidence; Runtime screenshots
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| rr-phase6b-goals-compact | [docs/delivery/evidence/2026-09-10-phase6b-goals-compact.png](evidence/2026-09-10-phase6b-goals-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6b-goals-registration-recovery | [docs/delivery/evidence/2026-09-10-phase6b-goals-registration-recovery.png](evidence/2026-09-10-phase6b-goals-registration-recovery.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6b-goals-wide | [docs/delivery/evidence/2026-09-10-phase6b-goals-wide.png](evidence/2026-09-10-phase6b-goals-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6c-evidence-compact | [docs/delivery/evidence/2026-09-10-phase6c-evidence-compact.png](evidence/2026-09-10-phase6c-evidence-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6c-evidence-wide | [docs/delivery/evidence/2026-09-10-phase6c-evidence-wide.png](evidence/2026-09-10-phase6c-evidence-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6e-help | [docs/delivery/evidence/2026-09-10-phase6e-help.png](evidence/2026-09-10-phase6e-help.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6e-search-compact | [docs/delivery/evidence/2026-09-10-phase6e-search-compact.png](evidence/2026-09-10-phase6e-search-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase6e-search-wide | [docs/delivery/evidence/2026-09-10-phase6e-search-wide.png](evidence/2026-09-10-phase6e-search-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| rr-phase5e-lifecycle-native | [docs/delivery/evidence/phase5e-lifecycle-native.png](evidence/phase5e-lifecycle-native.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 7b8828f1-697e-4140-9c9b-f5b3da58408d | [docs/delivery/evidence/rr10-needs-review.png](evidence/rr10-needs-review.png) | verificationEvidence | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.plans

- Path: [docs/delivery/plans](plans)
- Purpose: Delivery scope, dependencies, sequencing and rollout gates; historical plans are non-authoritative
- Allowed contents: Implementation plans
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [rr-full-product-architecture-plan-2026-09-06](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| rr-full-product-architecture-plan-2026-09-06 | [docs/delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md](plans/2026-09-06-full-product-architecture-and-delivery-plan.md) | document | supporting | proposed | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
