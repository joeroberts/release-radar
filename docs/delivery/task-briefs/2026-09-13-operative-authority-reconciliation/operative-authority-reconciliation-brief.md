# Operative authority reconciliation

Date: 2026-09-13. Status: active controlling brief for this bounded
documentation correction. Current authorization and delivery state remain in
`docs/delivery/progress.md`.

## Objective and outcome

Make Release Radar's operative documentation authority unambiguous while
preserving every accepted ADR byte-for-byte. Routine specification maintenance
belongs in owning mutable designs; agent rules belong in `AGENTS.md`; current
authorization and delivery state belong in `docs/delivery/progress.md`.

## Scope and exclusions

Correct only the authorized passages in `AGENTS.md`, the full-product plan, the
Phase 6 plan and the usable-project-lifecycle brief. Clarify ADR-006's bounded M1
approval in the full-product plan without claiming approval of its later
appendices. Keep catalog identities and the existing ADR-006 `active/controlling`
and lifecycle-brief `active/supporting` classifications.

Do not edit, move, rename, regenerate or delete any ADR. Do not begin the outcome
2 specification refresh or outcome 3 shared-execution adoption; change product
code, dependencies, tests, hooks, CI or configuration; launch Release Radar; read
or mutate owner data or SQLite; bind or accept a catalog; push, open a PR, merge,
tag, package, release or install. Preserve stopped Phase 6F and paused Phase 7.

## Dependencies, evidence and risks

Baseline is `892b1e11597dd1cff30f04818ecd7dac0605b897`. Chief-architect consultation
task `01a09b8a-1350-7c42-9d14-0aa07f28df40` resolved the wording from owner
evidence: task `01a05ea0-4aeb-7522-9e40-731c486fea5c`, owner turn
`01a05f0b-2bba-7fd0-8daa-0cad67b2e665` approved the substantive M1 direction and
the unchanged reviewed package while excluding the full-role matrix, mutable-brief
checksums, validation-of-validation, implementation and app/external mutations;
task `01a078bb-1a08-7222-96b1-58e842f5f809`, approval turn
`01a078dd-6bc6-73d1-922e-f65f5ed8feed` and merge turn
`01a07b74-d6d1-7281-8c0e-044b831004a8` support the completed lifecycle slice.
The material risk is overstating partial approval or turning historical prose into
new authority. There is no migration, compatibility or recovery behavior change.

## Test strategy and acceptance criteria

Run the repository-native documentation writer/checker for catalog and generated
index agreement, `git diff --check`, focused wording searches and a baseline-to-
candidate byte comparison of every existing ADR. Inspect the focused diff.
Acceptance requires the authorized authority rules and status clarifications,
unchanged stable artifact IDs and classifications, no changed ADR bytes, no
unrelated scope, and one fresh independent review with no Required finding.
Repository validation does not establish application acceptance or synchronization.

## Assignment, review and endpoint

Coordinator task `01a09b88-ccbb-79d3-9e5e-f3dcbf2cc708` owns coordination and
reviewer creation. Delivery-owner task
`01a09b8f-40de-7bb1-9a40-2bcbbe566cbb` owns this task worktree, the authorized
files and `docs/delivery/progress.md`; it was dispatched as `gpt-5.6-sol` / `high`
with ceiling `high`, though the runtime settings are not independently exposed.
The reviewer covers scope, approval attribution, authority consistency, unchanged
ADRs and catalog/document agreement. Only Required findings block. The endpoint
is scoped verified local commits only.
