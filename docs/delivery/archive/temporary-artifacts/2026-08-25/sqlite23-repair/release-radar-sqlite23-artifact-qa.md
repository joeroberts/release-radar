# SQLite-23 Release Artifact QA

**Result: PASS (artifact gate only)**

## Scope and classification

- **Required: 0.** Both requested durable Release artifacts are present and meet the artifact checks below.
- **Optional: 0.**
- **Out of scope:** owner runtime validation; launching either app; exercising **Initialize Project Tracking**; owner SQLite/container/Keychain access; UI verification; and any claim that the SQLite-23 workflow works for the owner. Those remain exclusively for owner validation after Delivery records this artifact gate.

## Actual bundle verification

| Check | `dist/ReleaseRadar.app` | `/Applications/ReleaseRadar.app` |
| --- | --- | --- |
| Exists | yes | yes |
| `codesign --verify --deep --strict --verbose=2` | pass (exit 0) | pass (exit 0) |
| Identifier | `com.rekonlabs.ReleaseRadar` | `com.rekonlabs.ReleaseRadar` |
| Version / build | `0.1.0` / `1` | `0.1.0` / `1` |
| CDHash | `893c9deab194bfbfbffc8a3966cb92e3c84f448b` | `893c9deab194bfbfbffc8a3966cb92e3c84f448b` |
| Main executable SHA-256 | `1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee` | `1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee` |
| `Contents/_CodeSignature/CodeResources` SHA-256 | `a7805f62f34929c63638c896ef85366532cf5365a658439fdede8140ac0e687a` | `a7805f62f34929c63638c896ef85366532cf5365a658439fdede8140ac0e687a` |
| Complete regular-file manifest | 12 files; SHA-256 `23f02ed7c4928a25e1a41ec62ada6ba8dc831a4d5c23572b8b10108b3428ffde` | 12 files; same SHA-256 |
| Symlink manifest (relative path + target, not followed) | 3 links; SHA-256 `3191e41574202baf9725748b8bc844dfc9998a1f06839825d2c433be24bce5f0` | 3 links; same SHA-256 |

The complete regular-file manifests were independently compared by relative path and per-file SHA-256, without following framework symlinks. The symlink relative-path/target manifests were compared separately. Both comparisons are equal.

Signing metadata also reports the expected Apple Development authority `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`, team `2UA854NLX4`, and Hardened Runtime (`flags=0x10000(runtime)`) for both main bundles. The observed main and Bridge Agent entitlement structures match the approved sandbox/app-group structures.

## Staging, install, and no-launch evidence

`dist/ReleaseRadar.app` remains present after installation. Direct-parent scans found no `.ReleaseRadar.stage.*`, `.ReleaseRadar.install.*`, `.ReleaseRadar.backup.*`, `.ReleaseRadar.failed.*`, `.install.*`, `.backup.*`, or `.failed.*` residue in either `dist/` or `/Applications`.

`script/build_and_run.sh` shows that `stage-release-no-launch` / `--stage-release-no-launch` and `install-staged-release-no-launch` / `--install-staged-release-no-launch` execute only staging/verification/promotion work; the `pkill` and `/usr/bin/open` calls are reachable only from the separate explicit launch modes (`run`, `debug`, `logs`, `telemetry`, and `verify`). This QA invoked none of those modes and did not launch, open, or terminate the app or access owner data.

The provided delivery authorization authorizes exactly those two nonlaunch modes. Artifact inspection can verify the resulting files and their equality, but it cannot by itself prove or exercise historic runtime behavior. No owner workflow claim is made.

## Limitation and owner gate

This is a signed-artifact result only. It does **not** demonstrate that Initialize Project Tracking succeeds for the owner, nor does it change the required terminal condition: the owner must personally launch `/Applications/ReleaseRadar.app`, exercise the workflow, and explicitly approve before any Done/Accepted claim.
