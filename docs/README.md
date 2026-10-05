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
