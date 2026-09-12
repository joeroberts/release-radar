# Restart helper signed installation and live check

Date: 2026-09-11

## Candidate and package

The package was built from reviewed closeout `07d8f8771a7a4bb87542a14b7c23e85436d68337`,
whose parent and last product-source commit is
`a60b1fd2f5c56d145bcbc634fd0e3f75a8765f26`. Package artifact commit
`69f939563f2e4044b00b91a0c1c22424aecb84a8`
contains `dist/ReleaseRadar-0.1.9-a60b1fd.dmg` and its staged application.

- Version/build: `0.1.9 (1)`
- DMG SHA-256: `6144d3cc1639a648f3f017b7fabe0552952dd59245b406cb48eb6b7509e282dc`
- Main executable SHA-256: `ac7e312203b3b900fb6e36d4e34be202e495640483f2554e45e7126ce922bf00`
- CodeResources SHA-256: `48be20d9762f9b5114017f2eaa4781fa12e627e6a551db27ca9789ab465d9f66`
- App CodeDirectory hash: `619175606f973a8482e2ccc2baa4603b04670151`
- Signature: Apple Development, team `2UA854NLX4`, Hardened Runtime enabled

The app and every nested executable passed strict signature verification. Effective
entitlements matched the source entitlement files for the app, bridge agent and
lifecycle helper. The DMG passed `hdiutil verify`, mounted read-only, contained the
application plus an `/Applications` symlink, and its 21 regular files and three
symlinks matched the staged bundle byte-for-byte and target-for-target. The package
is locally signed and not notarized.

## Installation and rollback

The installed `acc7401` app was preserved before replacement. Both the copied and
original moved bundles remain under:

`/Users/jroberts/Documents/Release Radar Backups/Pre-RestartHelper-0.1.9-2026-09-11.ReleaseRadarAppOnly.8KDP4L`

The earlier 0.1.7 rollback directory remains unchanged at:

`/Users/jroberts/Documents/Release Radar Backups/Pre-0.1.9-2026-09-11.ReleaseRadarOnly.PWddcC`

`/Applications/ReleaseRadar.app` now matches the package identity above and passes
strict nested-code verification. Release Radar launched from that path and retained
the visible Pursuit workspace. No plugin install, reinstall or removal was run, and
no direct SQLite access occurred.

## Live Restart helper result

Before replacement, lifecycle helper PID `48996` was still executing from the
preserved 0.1.7 rollback bundle. It remained alive through the app replacement.
When the newly installed app launched, its existing startup lifecycle recovery ran
before the Settings action was activated and replaced that stale process with PID
`67535` from `/Applications/ReleaseRadar.app`. The original stale-helper button
precondition therefore no longer existed. It was not recreated by downgrading,
re-registering or otherwise manufacturing owner state.

The installed **Restart helper** button was then activated exactly once. The
accessibility tree reported `Restarting lifecycle helper`, with the lifecycle
actions unavailable during the operation. The service returned with PID `67987`,
`runs = 1`, and executable path
`/Applications/ReleaseRadar.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper`.
The helper is signed by team `2UA854NLX4`, has Hardened Runtime enabled, and carries
the expected sandbox, bounded read paths, `/.codex/` write path and security-policy
lookup entitlements. Settings finished with `Lifecycle helper restarted. Plugin
status refreshed.` and re-enabled the actions. No Login Items approval or error
recovery prompt appeared.

The final plugin state remained honestly **Modified**, not **Installed**, because
the installed bytes do not match the last managed receipt. The UI retained the
existing reinstall guidance. Therefore the button's current-helper recovery path
passed, while the stale-helper button path remains not exercised because startup
recovery preempted it.

A later owner-supplied Settings screenshot shows plugin version `0.1.9` as
**Installed**. That screenshot is accepted as a later UI observation only: the
intervening actions were not observed, so it does not show that the Restart helper
action caused the state change and does not replace the contemporaneous
**Modified** result above.

The transient progress state was observed through accessibility. Native image
capture settled after the operation and did not preserve a distinct progress frame;
the retained progress PNG consequently matches the settled view and is not treated
as visual proof of the transient state.

- [Settings before activation](2026-09-11-restart-helper-before.png)
- [Attempted transient capture](2026-09-11-restart-helper-progress.png)
- [Settings after activation](2026-09-11-restart-helper-after.png)

## Remaining stale-helper gap

An attempted isolated process harness used an alternate launchd label and Mach
service, a custom service adapter, ad hoc unsandboxed helper fixtures and a
sentinel-driven exit. Although that experiment produced a green synthetic run,
independent review rejected it as proof: it did not exercise production
`SMAppService.unregister` or `SMAppService.register`, and its supporting machinery
was larger than the missing behavior. The harness and all production-source test
seams were withdrawn.

The accepted evidence therefore remains:

- the signed installed-app check above exercises the actual Settings button and a
  production `SMAppService`, but only with an already-current helper;
- repository tests exercise asynchronous service ordering and errors with the
  existing service double, exact stale-to-clean receipt restoration in the
  coordinator, and AppModel progress and final presentation.

The exact stale production `SMAppService` plus installed SwiftUI button combination
is still unexercised. A faithful isolated check needs a separately provisioned,
logged-in macOS account or macOS VM with its own GUI launchd domain, Codex home,
Release Radar store and installed application. In that environment an older signed
app can register and leave its real embedded helper running, the current signed app
can replace it, and the actual Settings button can perform the production
unregister/register handoff without touching the owner's working service or data.
No such account or VM was created or configured here. On this account the fixed
service label and Mach service are already occupied by the owner's live helper;
creating the stale precondition would require altering that working service and
associated owner state, which was not authorized.

## Preservation checks and limits

The installed plugin cache retained exactly four files and matched the newly
installed app's bundled plugin byte-for-byte:

| File | SHA-256 |
| --- | --- |
| `.codex-plugin/plugin.json` | `3a7398060b3711f9fa1f3fe9ad80e1f8b01efdb757175b317375355dfa2b28c6` |
| `.mcp.json` | `4e2f32f74da1c618990f0b434ac1b23044dcd2292ddf885202b76c1998726c71` |
| `skills/release-radar/SKILL.md` | `99632218216ee2ac9cec2b64a5f13bbe7a14317beae18ee1836fcfc99bf0b0ec` |
| `skills/shared-execution/SKILL.md` | `02bf2b540a893bbba689b79f5088c95a00d96a0cfa6dfd846c929b596e77b16b` |

This bounded check does not complete the broader owner acceptance guide. Managed
application inventory/readback remains unavailable because the recorded project
binding is incomplete; local documentation validation is not a substitute. Phase 7,
publication, notarization and cleanup remain outside this result.
