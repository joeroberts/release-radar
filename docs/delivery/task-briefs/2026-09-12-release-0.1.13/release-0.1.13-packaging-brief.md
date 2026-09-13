# Release Radar 0.1.13 packaging and installation

Status: completed; historical and non-authoritative. Delivery is integrated into
`main`; current authorization lives in [progress](../../progress.md#current-authorization).

Original assignment status (historical): owner-authorized local release delivery. This brief packages and installs
the independently reviewed bookmark and Help correction; it does not reopen
product design or implementation.

## Objective and outcome

Build a locally signed Release Radar `0.1.13` DMG from reviewed source
`c045f29ec09273dccabb033731f423d2d3850906` on the committed release baseline
`3fb119c303e7da5a96baa07d43d53e5d4860e44b`. Persist
`dist/ReleaseRadar-0.1.13.dmg` and a verified copy at
`/Users/jroberts/Downloads/ReleaseRadar-0.1.13.dmg`, create an annotated local
`v0.1.13` tag on the release-record commit, and install the verified staged app
at `/Applications/ReleaseRadar.app` without launching it. App and bundled
plugin versions must agree.

## Scope and exclusions

Update only established app/plugin version metadata, the recognized plugin
digest, focused version checks, release documentation, catalog/indexes, and
progress. Preserve the RDS revision
`3c2626102a2e97dd93f31fbc62b733085d6700ec`. Use the existing non-launch
stage/install commands and create an APFS image containing `ReleaseRadar.app`
and an `Applications` link.

No product behavior, RDS source, governing files, SQLite, Keychain, app launch,
notarization, push, PR, merge, GitHub release, public publication, or extra
rollback archive is included. Existing DMGs remain the rollback copies.

## Dependencies, risks and checks

The reviewed product closeout is `b7cc968`. Main risks are version/digest drift,
invalid nested signatures or entitlements, staged/mounted/installed identity
mismatch, and replacement of running release processes during authorized
installation. Run focused version tests; source signing validation; read-only
DMG checksum, mount and layout checks; staged/mounted identity comparisons;
and installed identity/signature checks. Use the available Apple Development
identity only; do not claim notarization or general-distribution readiness.

## Assignment and endpoint

This Terra/medium delivery task owns the release branch metadata, brief,
evidence, catalog/indexes, progress, local commits, local tag, DMG and the
authorized non-launch installation. One fresh independent Terra/high package
and version review is required after the version/source candidate, before final
release packaging. The authorized endpoint is the verified local commits,
annotated tag, DMG copies and installed app only.
