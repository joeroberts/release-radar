# Release Radar documentation

Current work, acceptance criteria, and delivery results belong to the owning
[GitHub issue](https://github.com/joeroberts/release-radar/issues). Canonical
product specifications and architecture decisions are maintained in the
[Release Radar Wiki](https://github.com/joeroberts/release-radar/wiki).

For Release Radar development assignments and task-relevant skill routing,
start with the repository [agent instructions](../AGENTS.md) and the Wiki's
[RR Development Delegation Model](https://github.com/joeroberts/release-radar/wiki/RR-Development-Delegation-Model).
The owning issue or assignment records exact delivered skill revisions and
actual discovery or invocation results; this documentation index does not prove
that a reusable skill is installed or available in the current session.

Repository documentation retains the current [delivery snapshot](delivery/progress.md)
and repository-owned [design references](design/README.md). For proposed
whole-product work, use the published
[full-product architecture and delivery plan](https://github.com/joeroberts/release-radar/wiki/Full-Product-Architecture-and-Delivery-Plan).

## Delivered role routing

Read this table only when the repository `AGENTS.md` selects one of these
delivered role methods. This is the authoritative routing detail for their
invocation; the discovered skill supplies its operating method and the linked
Wiki role remains Release Radar project authority.

| Entry point | Invoke with | Execution, result and failure response |
| --- | --- | --- |
| `senior-software-developer` | An authorized application or tooling feature, defect correction or bounded refactor; complete outcome, criteria and exclusions, exact candidate and endpoint, reproduction/expected behavior, relevant contracts, dirty-work context and project ownership. | This instruction-only role method localizes the implementation boundary, makes the smallest coherent change covering implicated normal/error/recovery behavior, preserves contracts and unrelated work, and hands the exact candidate to QA, review and delivery. It is not an architecture-only, QA, CI/CD or cleanup role; missing inputs and checks remain explicit rather than invented or promoted to completion. |
| `senior-qa-engineer` | A bounded behavior change or defect needing verification; complete criteria, exact candidate and target identity, environment, design/risk inputs, existing tests/fixtures, runtime access, allowed test data, ownership and evidence destination. | This instruction-only role method maps every criterion to expected and actual observations and a `Passed`, `Failed`, `Missing`, `Blocked` or `Not Run` result, then exercises only relevant behavior and integration, failure, persistence, recovery, UI or accessibility boundaries. QA owns RR tests, fixtures and execution; it does not implement, independently review or authorize delivery, and a target mismatch or unavailable runtime stays unverified. |
| `ux-architect` | A bounded user-facing journey, guidance or presentation change; user job and criteria, approved constraints/design, representative states, supported platforms/sizes, exact candidate and available runtime/design evidence. | This instruction-only role method keeps observed, proposed and unverified claims separate while assessing navigation, language, states, keyboard/focus, accessibility, responsive presentation and recovery. It returns Required, Optional and Unresolved findings without inventing design approval or runtime evidence; backend-only work does not select it, and source or mockups alone do not prove delivered interaction. |
| `senior-frontend-software-developer` | An authorized substantive browser interaction or diagnosis; outcome and criteria, exact candidate/endpoint, framework/runtime, approved design, component/API/state contracts, browsers/viewports, reproduction, runtime access and role ownership. | This instruction-only role method implements the smallest coherent browser change, applicable loading/empty/validation/error/cancellation/recovery states, established stale-request handling, keyboard/focus/accessibility and responsive behavior while preserving consumer and trust contracts. It is not a native, hosting, deployment, QA or CI/CD role; observed browser behavior remains separate from source inference and the exact candidate goes to QA and review. |
| `senior-software-security-engineer` | A concrete security design, changed trust boundary or supplied finding; exact candidate/question, assets and data classification, actors and grants, trust crossings, authorized environment/actions and safe evidence or fixtures. | This instruction-only role method examines only relevant security boundaries, classifies conclusions as demonstrated, plausible or unknown, and recommends the smallest effective correction with validation and residual risk. It does not start an unauthorized scan, live exploit, secret access, owner-data mutation or destructive action; specialized security workflows are selected only when their trigger and authority fit. |
| `senior-ci-cd-engineer` | A bounded GitHub Actions, check, runner/cache, build, packaging or explicitly authorized delivery path; exact repository/revision/version, event trust, runner/permissions, native commands and owners, artifact/consumers and endpoint. | This instruction-only role method preserves least privilege and exact source/artifact identity across event, checkout, cache, artifact and publication boundaries, reporting configured, built, installed, running and verified as separate observed states. It does not own application work or QA test design, start a release for documentation, infer credentials or publishing authority, or duplicate/overwrite artifacts to cure partial delivery. |
| `senior-python-developer` | An authorized substantive Python or FastAPI implementation or diagnosis; outcome, candidate/reproduction, exclusions and endpoint, pinned Python/framework/server/dependency versions, affected route/model/dependency/lifespan/persistence/auth contracts, tooling and expected normal/error/cancellation/cleanup behavior. | This instruction-only role method traces the actual request and resource lifetime, preserves API/error/auth contracts, and makes the smallest pinned-runtime-compatible correction for relevant validation, blocking/async, dependency, lifespan or failure behavior. Plain Python does not acquire FastAPI or a service scaffold; missing runtime evidence stays unverified, and QA owns focused concurrency, cleanup, override/lifespan and authenticated-failure checks. |

<!-- release-radar-docs:v1:start -->

## Collection: docs

- Path: [docs](.)
- Purpose: Release Radar documentation, current authority, and retained history
- Allowed contents: Catalog and navigation indexes; Design and delivery collections
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [c48466fb-a4fd-4f9e-96bf-967dfa173216](README.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| c48466fb-a4fd-4f9e-96bf-967dfa173216 | [docs/README.md](README.md) | collectionIndex | supporting | active | none | none |

### Children

- [delivery](delivery) — leaf; Current delivery status
- [design](design/README.md) — indexed; Repository-owned visual references

## Leaf collection: delivery

- Path: [docs/delivery](delivery)
- Purpose: Current delivery status
- Allowed contents: Current progress ledger
- Prohibited contents: Owner data and credentials; Temporary build output
- First read: [450e84de-703b-4dcd-ad1a-7fddfee0d1d9](delivery/progress.md)
- Archive destination: none
- Historical boundary: archived artifacts are non-authoritative.

### Artifacts

| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| 450e84de-703b-4dcd-ad1a-7fddfee0d1d9 | [docs/delivery/progress.md](delivery/progress.md) | document | controlling &#40;delivery.current-state&#41; | active | none | none |

### Children

Leaf: no child collections.

<!-- release-radar-docs:end -->
