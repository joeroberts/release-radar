# Delivery documentation

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

- [delivery.archive](archive/README.md) — indexed; Historical delivery records; never current task eligibility
- [delivery.evidence](evidence) — leaf; Durable verification evidence from delivered work
- [delivery.plans](plans) — leaf; Current implementation plans; progress determines task eligibility
- [delivery.task-briefs](task-briefs/README.md) — indexed; Reviewed task scopes; current progress determines the open task

## Leaf collection: delivery.evidence

- Path: [docs/delivery/evidence](evidence)
- Purpose: Durable verification evidence from delivered work
- Allowed contents: Immutable test evidence; Runtime screenshots
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: none
- Archive destination: [delivery.archive](archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 96b10404-6291-4cc8-beb9-c0e2e1dff704 | [docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json](evidence/2026-08-30-rr-r10-task-2a-red-evidence.json) | verificationEvidence | nonAuthoritative | completed | none | none |
| fc2ef1e4-36f7-4f32-8e1a-e03a5e59ce7d | [docs/delivery/evidence/2026-09-02-rr-r10-task-10-ui.md](evidence/2026-09-02-rr-r10-task-10-ui.md) | verificationEvidence | nonAuthoritative | completed | none | none |
| 7b3c9e04-c628-492e-910a-6818c132bc10 | [docs/delivery/evidence/2026-09-02-rr-r10-task-11a-SHA256SUMS](evidence/2026-09-02-rr-r10-task-11a-SHA256SUMS) | checksumManifest | nonAuthoritative | completed | none | none |
| 67abec4d-33b5-42be-89c3-e25cf84a20e8 | [docs/delivery/evidence/2026-09-02-rr-r10-task-11a-candidate.json](evidence/2026-09-02-rr-r10-task-11a-candidate.json) | verificationEvidence | nonAuthoritative | completed | none | none |
| 7c39bcd0-76cc-4b5f-a461-f5257c245188 | [docs/delivery/evidence/2026-09-02-rr-r10-task-11a-integration-staging.md](evidence/2026-09-02-rr-r10-task-11a-integration-staging.md) | verificationEvidence | nonAuthoritative | completed | none | none |
| bddf4926-4ab5-42e8-8af1-bc0b2854b1f2 | [docs/delivery/evidence/2026-09-02-rr-r10-task-11b-installation.md](evidence/2026-09-02-rr-r10-task-11b-installation.md) | verificationEvidence | nonAuthoritative | completed | none | none |
| a5d9d0f5-d689-405d-b175-f88534219a1f | [docs/delivery/evidence/2026-09-02-rr-r10-task-5-ui.md](evidence/2026-09-02-rr-r10-task-5-ui.md) | verificationEvidence | nonAuthoritative | completed | none | none |
| 0199bdf8-78d1-460e-abe2-519f0fd34e0b | [docs/delivery/evidence/mdcp-m2c-onboarding-repair-compact.png](evidence/mdcp-m2c-onboarding-repair-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 2497cc96-d6c8-42ea-87b3-1f6b7cabda8b | [docs/delivery/evidence/mdcp-m2c-onboarding-staged-wide.png](evidence/mdcp-m2c-onboarding-staged-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| ab3b7be3-fc39-48cf-8101-0fc4d24845ac | [docs/delivery/evidence/mdcp-m2c-overview-repair-compact.png](evidence/mdcp-m2c-overview-repair-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| c7e61a92-4787-4f7d-93de-79b271e163e2 | [docs/delivery/evidence/mdcp-m2c-overview-staged-wide.png](evidence/mdcp-m2c-overview-staged-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| c57db624-74d1-439c-83f6-03033273c2fb | [docs/delivery/evidence/mdcp-m3c-confirmation-1100.png](evidence/mdcp-m3c-confirmation-1100.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| ed21cbac-018c-40d2-b681-96015909e9db | [docs/delivery/evidence/mdcp-m3c-confirmation-620.png](evidence/mdcp-m3c-confirmation-620.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 2f2246aa-e957-454f-9c9b-faf80cb410c6 | [docs/delivery/evidence/mdcp-m3c-evidence-1100.png](evidence/mdcp-m3c-evidence-1100.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 849e2bb8-5267-4bf0-8261-d5046970abaa | [docs/delivery/evidence/mdcp-m3c-evidence-620.png](evidence/mdcp-m3c-evidence-620.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 52cf86e7-e8fc-44eb-9558-aab94983f70b | [docs/delivery/evidence/mdcp-m3c-maintenance-read-only.png](evidence/mdcp-m3c-maintenance-read-only.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| ca37c279-0dbb-4061-b379-bc557159e907 | [docs/delivery/evidence/mdcp-m3c-phase-less-overview.png](evidence/mdcp-m3c-phase-less-overview.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 2168caea-798e-4895-acad-27b249b57bf6 | [docs/delivery/evidence/mdcp-m5-onboarding-unavailable-compact.png](evidence/mdcp-m5-onboarding-unavailable-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 9f047ff0-f55e-47bb-a46d-5b40d9f51146 | [docs/delivery/evidence/mdcp-m5-onboarding-unavailable-wide.png](evidence/mdcp-m5-onboarding-unavailable-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| fb8da0f4-d5e9-4631-b571-5f5ff6c2f017 | [docs/delivery/evidence/mdcp-m5-overview-current-wide.png](evidence/mdcp-m5-overview-current-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| ef0a5b3e-c4de-4007-92ac-36d4cb2ecc5c | [docs/delivery/evidence/mdcp-m5-overview-update-compact.png](evidence/mdcp-m5-overview-update-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 94fa2ee5-a1e3-43a6-800e-78d94446f16b | [docs/delivery/evidence/rr-r10-task10-board-compact.png](evidence/rr-r10-task10-board-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| a21d7257-8f90-479a-a76b-0d69dfc04eca | [docs/delivery/evidence/rr-r10-task10-board-wide.png](evidence/rr-r10-task10-board-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| b76d1e50-d364-4dbf-b1aa-c31f675be7c7 | [docs/delivery/evidence/rr-r10-task10-filtered-wide.png](evidence/rr-r10-task10-filtered-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| a1e6528a-4baf-4814-aef8-b2080506cddc | [docs/delivery/evidence/rr-r10-task10-needs-review.png](evidence/rr-r10-task10-needs-review.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| b6fff764-f6dd-4d5f-9015-ad24aa679694 | [docs/delivery/evidence/rr-r10-task5-accessibility-compact.txt](evidence/rr-r10-task5-accessibility-compact.txt) | verificationEvidence | nonAuthoritative | completed | none | none |
| db824e94-8967-4901-9fb5-70f882b64cf1 | [docs/delivery/evidence/rr-r10-task5-accessibility-wide.txt](evidence/rr-r10-task5-accessibility-wide.txt) | verificationEvidence | nonAuthoritative | completed | none | none |
| 766a793e-6b1e-4003-8f71-658f269ab46f | [docs/delivery/evidence/rr-r10-task5-compact-last-tasks.png](evidence/rr-r10-task5-compact-last-tasks.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| f4ffe8b5-2802-40ef-8747-8eddd233c0f5 | [docs/delivery/evidence/rr-r10-task5-increased-contrast-compact.png](evidence/rr-r10-task5-increased-contrast-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| f48dfad6-7632-49a5-8709-76a4e0da8cbc | [docs/delivery/evidence/rr-r10-task5-increased-contrast-wide.png](evidence/rr-r10-task5-increased-contrast-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 08a40605-af59-4fd7-996e-84f6052c6477 | [docs/delivery/evidence/rr-r10-task5-loaded-compact.png](evidence/rr-r10-task5-loaded-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 751e813c-3d89-4546-876f-faef75588785 | [docs/delivery/evidence/rr-r10-task5-loaded-wide.png](evidence/rr-r10-task5-loaded-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 57b45ac5-b53b-4d5f-86a2-fa2046e525ad | [docs/delivery/evidence/rr-r10-task5-no-plan-compact.png](evidence/rr-r10-task5-no-plan-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 9101f56b-2e34-41a6-879b-00e5a24b1591 | [docs/delivery/evidence/rr-r10-task5-no-plan-wide.png](evidence/rr-r10-task5-no-plan-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 304d9a72-624f-4ddb-b9dd-05c7e75d6d2c | [docs/delivery/evidence/rr-r10-task5-unavailable-compact.png](evidence/rr-r10-task5-unavailable-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| ddff4197-4f3b-4fe8-9a20-c3ab4809bb79 | [docs/delivery/evidence/rr-r10-task5-unavailable-wide.png](evidence/rr-r10-task5-unavailable-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| a14ff940-cfc1-4735-974b-895ab63f1364 | [docs/delivery/evidence/rr-r9-active-phase-board-compact.png](evidence/rr-r9-active-phase-board-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| b445b788-23e7-4630-a4d1-648845c1ebcc | [docs/delivery/evidence/rr-r9-active-phase-board-wide.png](evidence/rr-r9-active-phase-board-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 0ad29467-a31f-4574-9a98-05b2188a540f | [docs/delivery/evidence/rr-r9-active-phase-overview.png](evidence/rr-r9-active-phase-overview.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 7e761c7f-890f-46f8-80ac-17139b378c52 | [docs/delivery/evidence/rr-r9-active-phase-recovery.png](evidence/rr-r9-active-phase-recovery.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| f3745dd3-d7c2-48d2-b4b4-66e977c22067 | [docs/delivery/evidence/rr06-fix1-overview.png](evidence/rr06-fix1-overview.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 60bfe86b-4516-4c2b-bb2d-af7270316152 | [docs/delivery/evidence/rr06-fix1-projects.png](evidence/rr06-fix1-projects.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 596cc16a-071c-483e-9ca8-67e7b3d20c6b | [docs/delivery/evidence/rr06-owner-narrow.png](evidence/rr06-owner-narrow.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 0df8831b-ca74-470f-97b5-03bc346ecb21 | [docs/delivery/evidence/rr06-owner-wide.png](evidence/rr06-owner-wide.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| bb97491f-4fd6-42a1-b19f-e16d635af1ad | [docs/delivery/evidence/rr07-activity.png](evidence/rr07-activity.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 1afeecc9-08fc-4299-8d5d-3eb562a4c40d | [docs/delivery/evidence/rr07-dependencies.png](evidence/rr07-dependencies.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| d3584218-3f79-4f1e-bcb8-1078dcc88854 | [docs/delivery/evidence/rr07-needs-review.png](evidence/rr07-needs-review.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 11bbbbe0-5784-4d8b-b552-705d5b033979 | [docs/delivery/evidence/rr07-settings.png](evidence/rr07-settings.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 887bdd6c-12b6-49e6-878e-51666796e566 | [docs/delivery/evidence/rr10-activity.png](evidence/rr10-activity.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 56d21a68-625e-4cef-ae0c-2804acff28fb | [docs/delivery/evidence/rr10-board-compact.png](evidence/rr10-board-compact.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| c1dd4c3a-5460-48b8-b3d7-99645bee278c | [docs/delivery/evidence/rr10-dependencies.png](evidence/rr10-dependencies.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 7b8828f1-697e-4140-9c9b-f5b3da58408d | [docs/delivery/evidence/rr10-needs-review.png](evidence/rr10-needs-review.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| e0a1bf9e-5a4c-4a0d-ae90-bda8d9a93083 | [docs/delivery/evidence/rr10-notifications.png](evidence/rr10-notifications.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 3dae8a2b-fa2a-4472-a09b-ad00971e947e | [docs/delivery/evidence/rr10-onboarding-failure.png](evidence/rr10-onboarding-failure.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| 199a56ed-2513-436b-ad69-36e4d45eef7c | [docs/delivery/evidence/rr10-projects-overview-board-detail.png](evidence/rr10-projects-overview-board-detail.png) | verificationEvidence | nonAuthoritative | completed | none | none |
| dfa76052-348a-42ae-ae62-4044c29a40b7 | [docs/delivery/evidence/rr10-settings.png](evidence/rr10-settings.png) | verificationEvidence | nonAuthoritative | completed | none | none |

### Children

Leaf: no child collections.

## Leaf collection: delivery.plans

- Path: [docs/delivery/plans](plans)
- Purpose: Current implementation plans; progress determines task eligibility
- Allowed contents: Implementation plans
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [cd044b85-6519-4330-ae3c-dc0d9c20a65e](plans/2026-08-29-delivery-goals-roadmap-readiness.md)
- Archive destination: [delivery.archive](archive)
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| cd044b85-6519-4330-ae3c-dc0d9c20a65e | [docs/delivery/plans/2026-08-29-delivery-goals-roadmap-readiness.md](plans/2026-08-29-delivery-goals-roadmap-readiness.md) | document | controlling &#40;delivery.rr-r10-implementation&#41; | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
