# Release Radar SQLite-23 artifact Security/Privacy verification

**Decision: PASS**  
**Required findings: 0**  
**Optional findings: 0**

Verification was read-only and nonlaunching on 2026-08-25. The inspected artifacts were:

- `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`
- `/Applications/ReleaseRadar.app`

No repository file, bundle, Git state, app-owned data, owner database, container, or Keychain item was modified or accessed by this verifier. The app and its embedded executables were not launched.

## Required verification results

### Both main app bundles

Both durable bundle paths independently passed `codesign --verify --deep --strict`. For each bundle, both `CFBundleIdentifier` and the signed-code identifier are exactly:

`com.rekonlabs.ReleaseRadar`

Both main signatures have:

- CodeDirectory flags: `0x10000(runtime)` (Hardened Runtime)
- Leaf authority: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`
- Team identifier: `2UA854NLX4`
- CDHash: `893c9deab194bfbfbffc8a3966cb92e3c84f448b`

Canonical plist comparison established that each main app has exactly four entitlement keys, with no extras:

- `com.apple.security.app-sandbox = true`
- `com.apple.security.application-groups = ["2UA854NLX4.com.rekonlabs.ReleaseRadar"]` (exactly one value)
- `com.apple.security.files.user-selected.read-only = true`
- `com.apple.security.network.client = true`

`com.apple.security.get-task-allow` is absent because it is not present in that exact four-key dictionary.

### Embedded `ReleaseRadarBridgeAgent`

The Bridge Agent at both bundle paths independently passed strict signature verification. Each has:

- Signed identifier: `com.rekonlabs.ReleaseRadarBridgeAgent`
- CodeDirectory flags: `0x10000(runtime)`
- Leaf authority: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`
- Team identifier: `2UA854NLX4`
- CDHash: `d4741978cc18870f5ced18287c0a1c48f27ece54`

Canonical plist comparison established exactly two Bridge entitlement keys, with no extras:

- `com.apple.security.app-sandbox = true`
- `com.apple.security.application-groups = ["2UA854NLX4.com.rekonlabs.ReleaseRadar"]` (exactly one value)

The Bridge has no `get-task-allow` or any other entitlement key.

### All embedded signed code

For each bundle, every discovered executable and framework independently passed `codesign --verify --strict`; every target has the exact configured leaf authority and team above. The five verification targets per bundle were:

- Main executable, identifier `com.rekonlabs.ReleaseRadar`
- `ReleaseRadarBridgeAgent`, identifier `com.rekonlabs.ReleaseRadarBridgeAgent`
- `ReleaseRadarAgentTools`, identifier `com.rekonlabs.ReleaseRadarAgentTools`
- `ReleaseRadarCore.framework`, identifier `com.rekonlabs.ReleaseRadarCore`
- The framework's `ReleaseRadarCore` Mach-O executable, identifier `com.rekonlabs.ReleaseRadarCore`

All five also reported the Hardened Runtime flag.

### Staged/installed identity and promotion residue

The staged and installed identity tuple is identical:

- CDHash: `893c9deab194bfbfbffc8a3966cb92e3c84f448b`
- Identifier: `com.rekonlabs.ReleaseRadar`
- Short version: `0.1.0`
- Build: `1`
- Main executable SHA-256: `1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee`
- Signed `CodeResources` SHA-256: `a7805f62f34929c63638c896ef85366532cf5365a658439fdede8140ac0e687a`

Direct byte comparison also matched the two main executables and the two signed `CodeResources` manifests. The `dist/ReleaseRadar.app` bundle remains present after installation.

Fresh checks found zero `.ReleaseRadar.stage.*`, `.ReleaseRadar.install.*`, `.ReleaseRadar.backup.*`, or `.ReleaseRadar.failed.*` paths under either `dist` or `/Applications`.

### Nonlaunch/privacy execution boundary

Static inspection of `script/build_and_run.sh` confirms that `--stage-release-no-launch` calls only the Release build/stage path and `--install-staged-release-no-launch` calls only the staged-install path. `pkill` and `/usr/bin/open` exist only behind the explicit `run`, `debug`, `logs`, `telemetry`, and `verify` launch modes.

The retained controller-session provenance at `/tmp/release-radar-sqlite23-packaging-execution-evidence.md` records these exact commands, in order, both with exit `0`:

1. `script/build_and_run.sh --stage-release-no-launch`
2. `script/build_and_run.sh --install-staged-release-no-launch`

That evidence records that no launch mode, `open`, `pkill`, app executable, database command, or Keychain command was invoked; a post-install read-only `pgrep` found no `ReleaseRadar` process. This verifier independently confirmed the resulting artifacts and zero transaction residue. Historical command absence is not encoded in an app bundle, so this execution-boundary conclusion appropriately relies on the retained controller-session provenance plus the reviewed script call paths.

## Classification

### Required — 0

No signing, Hardened Runtime, authority, team, identifier, entitlement, embedded-code, bundle-identity, preservation, or transaction-residue defect was found.

### Optional — 0

No optional artifact hardening change is proposed within this owner-local Apple Development handoff.

### Out of scope

- Owner runtime validation of **Initialize Project Tracking**: not performed and not claimed.
- Done/Accepted or owner approval: not granted by this review.
- Developer ID distribution, notarization, App Store distribution, and general Gatekeeper readiness: not evaluated or claimed; the accepted boundary is the configured Apple Development owner-local handoff.
- Product behavior, owner database contents, app container contents, Keychain contents, and live bridge behavior: deliberately not accessed or exercised.

## Final disposition

**PASS — Required findings: 0.** Both actual Release artifacts satisfy the required strict signing, Hardened Runtime, exact identity/team, fail-closed exact entitlement, embedded-code, staged/installed identity, preservation, residue, and nonlaunch packaging boundaries. Owner runtime validation remains pending and is not implied by this PASS.
