# ADR-007: Proportional Delivery Validation

- Status: Accepted; owner-approved
- Date: 2026-09-01

## Context

The mandatory all-role delivery model caused recursive validation, oversized
briefs, duplicated evidence, and operational-context inflation. The process
could become larger than the product change without adding corresponding
confidence.

## Decision

The repository-root `AGENTS.md` is the operative risk-triggered delivery policy.
Work uses three stages:

1. **Start:** authorization, scope, dependencies, and material risks are clear.
2. **Implement:** behavior changes use test-first development and focused
   repository-native checks.
3. **Complete:** the changed behavior is directly verified and receives the
   independent review required by its risks.

Every material implementation retains an independent reviewer other than its
implementer. Ordinary documentation needs one independent review and applicable
documentation validation; ordinary code behavior needs focused tests and one
independent code or QA review. Architecture, Security/Privacy, UX, and TPM
reviews are added only for the triggers defined in `AGENTS.md`. Delivery
Management records current state and evidence rather than supplying another
technical approval. Reviewers explicitly requested by the owner remain
required for that task.

Direct product evidence takes precedence over process evidence. Successful
direct tests and independent reviews are terminal unless they identify a
defect; reviews are not recursively reviewed. Mutable plans, briefs, indexes,
and progress records are not checksum-controlled. Immutable evidence may be.

Older mandatory review ceremony is superseded for unopened work. Older product,
persistence, security, test, dependency, and acceptance requirements remain
valid. Completed work is not retroactively invalidated, and historical plans,
briefs, and evidence remain unchanged.

This decision governs M2–M8 of the Managed Repository Documentation Contract
and all other unopened repository work.

## Rationale

Risk-triggered validation preserves independent implementation review and the
project's authorization, data, security, and verification boundaries while
keeping evidence proportional to the change. It directs effort toward
observable behavior and concrete risks instead of proof that another process
step occurred.

## Supersession

This ADR supersedes pre-M1A requirements that mandate full-role review matrices,
mutable-document checksums, exact-brief hashes, commit-parent formulas, repeated
remote-equality gates, or validation of another validation for unopened work.
It does not supersede their product or safety requirements and does not alter
completed records.
