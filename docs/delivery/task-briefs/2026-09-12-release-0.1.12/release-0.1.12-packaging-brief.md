# Release Radar 0.1.12 packaging

Status: owner-authorized local packaging and local-tag endpoint. This brief
packages the independently reviewed RDS toolbar adoption; it does not reopen
product design or implementation.

## Objective and outcome

Build a locally signed Release Radar `0.1.12` DMG from reviewed toolbar source
`8cd2bc634b8c06d04ec59e00e477ebc32f308192`, write the repository artifact at
`dist/ReleaseRadar-0.1.12.dmg`, copy the verified image to the owner's
Downloads folder, and create an annotated local `v0.1.12` tag on the release
record commit. The app and bundled plugin versions must agree.

## Scope and exclusions

Update only established app/plugin version metadata, the recognized plugin
digest and tightly related version checks where the packaging contract requires
them. Preserve RDS revision `3c2626102a2e97dd93f31fbc62b733085d6700ec`.
Use `script/build_and_run.sh stage-release-no-launch` and an APFS image with
`ReleaseRadar.app` and an `Applications` link. Record concise durable evidence
and catalog/index/progress entries.

No toolbar behavior, RDS source, governing instructions, test infrastructure,
installed app, helpers, plugins, SQLite, Keychain, launch, notarization, push,
PR, merge, release publication, or tag push is included.

## Dependencies, risks and checks

The assigned baseline is `7e5bd418d55cb39c2bc0ab3f2a1cdddc5c71b66d`; the
reviewed candidate is in its ancestry. Main risks are version/digest drift,
invalid nested signatures or entitlements, and a staged/mounted image mismatch.
Run focused version/package tests, source signing validation, read-only DMG
mount/layout checks, staged/mounted identity comparisons, and image checksums.
Use the available Apple Development identity only; do not claim notarization or
general distribution readiness.

## Assignment and endpoint

This Terra/medium delivery task owns the release branch documentation, metadata,
artifact, evidence, local commits and tag. One independent package/version
review is required for the resulting candidate. The authorized endpoint is the
local commits, local annotated tag and verified Downloads copy only.
