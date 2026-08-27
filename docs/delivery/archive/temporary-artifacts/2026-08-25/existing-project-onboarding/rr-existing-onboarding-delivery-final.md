Add a final acceptance block under [`docs/delivery/progress.md`](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md) within `### Existing-project onboarding — task split and preimplementation gate`, after the current “Completion evidence required here” bullet.

Use entries to this effect:

- `Status:` **Attach Folder to Existing Project** is implemented and independently accepted for code review, architecture, and security/privacy; **Import Existing Project** remains blocked and unimplemented.
- `Implementation boundary:` attachment flows only through `FolderProjectOnboarding.associateFirstProjectRoot`; no onboarding `inspect`/`prepare`/`requestFirstPhaseDefinition`/`finish`, importer path, Markdown discovery, marker creation, or dashboard-open side effect was introduced.
- `Focused verification:` final focused tests passed 39/39 after the last changes.
- `Full regression verification:` full suite passed 154/154 at `/tmp/release-radar-existing-onboarding-full/Logs/Test/Test-ReleaseRadar-2026.08.25_08-54-30--0400.xcresult`.
- `Build evidence:` fresh Release build succeeded at `/tmp/release-radar-existing-onboarding-release/Build/Products/Release/ReleaseRadar.app`.
- `Live isolated QA evidence:` native Add Project title/window, red close, Cancel, Escape, exact `Attach Folder to Existing Project` label, eligible Rekon Pursuit selection, native folder picker, responsive layouts at about `760x520` and `900x650`, and zero root/bookmark/audit writes after dismissals were all directly verified in an isolated container.
- `QA result:` no Required findings; **CONDITIONAL GO** only because Computer Use disconnects immediately after the `NSOpenPanel` closes, so the final committed return-to-Projects/live confirmation could not be directly observed in that session.
- `Architecture:` GO, Required 0; no ADR change.
- `Security/privacy:` GO, Required 0; isolated dismissal paths produced no root/bookmark/audit writes and no owner data access.
- `Code review:` GO, Required 0.
- `Risk / residual evidence gap:` the only remaining gap is unobserved final live confirm/return behavior after picker dismissal because of the Computer Use disconnect, not a discovered product defect.
- `Portable import blocker:` **Import Existing Project** remains **NO-GO** until Release Radar has an authoritative structured portable archive plus exporter-produced fixture. `docs/delivery/dashboard-status.json` Markdown-adjacent material is non-authoritative and the partial Rekon seed importer cannot be reused.
- `Next eligible task:` none within existing-project onboarding beyond resolving the live-observation tooling gap if required for unconditional QA closure; portable import planning/implementation stays closed pending authoritative exporter/archive fixture. After that, the next separately releasable product work is the deferred RR-R7 packaging/handoff path.

Delivery Manager end state for this gate: **CONDITIONAL GO**.