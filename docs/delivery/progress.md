# Release Radar progress
Updated: October 5, 2026.
## Current outcome

Epic #160 is executing the authorized reusable-skill delivery. All eleven role
implementations exist, but only #230 is closed. #174 and #228 retain active
source or QA work; #162, #164, #170, #171, #172, #173, #234, #235, #236, #237,
#238, #239, and #240 are in delivery evidence. #161 and #169 are closed.
## Active links

- [Epic #160](https://github.com/joeroberts/release-radar/issues/160) owns the
  complete outcome and child acceptance criteria.
- [#173](https://github.com/joeroberts/release-radar/issues/173),
  [#174](https://github.com/joeroberts/release-radar/issues/174),
  [#228](https://github.com/joeroberts/release-radar/issues/228),
  [#238](https://github.com/joeroberts/release-radar/issues/238),
  [#239](https://github.com/joeroberts/release-radar/issues/239), and
  [#240](https://github.com/joeroberts/release-radar/issues/240) have bounded
  role lanes. #174 corrected normal-policy discovery runs passed; its
  delivered-child audit remains pending; #228 initial RR `1960d6b`/Wiki `bdb0901` block
  passed but final all-version/new-host integration is pending. #173 QA/review
  passed ai-tools `9aee996` and Wiki `b76f29d`; #172 CI is ready; #238 passed final review at `58cbd4d`.
  #239 QA/review passed `e1e16be`; #240 passed `18ef366` with its explicit pinned-runtime handoff; CI is ready for #172, #173, #238, #239, and #240.
- [#162](https://github.com/joeroberts/release-radar/issues/162),
  [#164](https://github.com/joeroberts/release-radar/issues/164),
  [#170](https://github.com/joeroberts/release-radar/issues/170),
  [#171](https://github.com/joeroberts/release-radar/issues/171),
  [#234](https://github.com/joeroberts/release-radar/issues/234),
  [#235](https://github.com/joeroberts/release-radar/issues/235),
  [#236](https://github.com/joeroberts/release-radar/issues/236), and
  [#237](https://github.com/joeroberts/release-radar/issues/237) require their
  remaining review, delivery, installation, or fresh-use evidence.
- [#231](https://github.com/joeroberts/release-radar/issues/231) and
  [#233](https://github.com/joeroberts/release-radar/issues/233) remain gated
  by hosted-runner acquisition during an [active GitHub Actions incident](https://www.githubstatus.com/incidents/3q1yb5m7ltvb);
  do not retry, bypass, merge, or close pending owner direction. [#232](https://github.com/joeroberts/release-radar/issues/232) remains in review.
- [#161](https://github.com/joeroberts/release-radar/issues/161),
  [#169](https://github.com/joeroberts/release-radar/issues/169), and
  [#230](https://github.com/joeroberts/release-radar/issues/230) are closed.
- [Wiki Home](https://github.com/joeroberts/release-radar/wiki) routes current
  development standards and role guidance.
## Current constraints

#177 and #178 remain closed completed inputs; do not reopen without a newly
authorized defect. Do not close a child from source delivery or a completed task
alone: record its criteria, merged source, stable installation/discovery, exact
fresh-session invocation, checks, and review.
#169 retains seven run-owned temporary QA evidence directories pending explicit
owner deletion authority; they are not durable deliverables or a closure defect.
Its broad cleanup prune also removed unrelated stale local remote-tracking
references. Exact recovery is unavailable because retained pre-operation output
lacks their SHAs; no guessed recovery was attempted and no source, branch, or
worktree was deleted.

## Next action

Record queued #174, #228, and #240 delivery states after the GitHub API
cooldown is explicitly lifted. Continue active lanes and collect remaining
evidence; #228 must reconcile the original eight roles plus eleven added roles.
