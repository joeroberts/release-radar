# SQLite-23 nonlaunch packaging execution evidence

Repository working directory:

`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`

## Stage

Exact command invoked by the controller on 2026-08-25:

```sh
script/build_and_run.sh --stage-release-no-launch
```

Observed result: exit code `0`. The output identified Release configuration,
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, successful build, strict verification
of the built and copied bundles, and ended with:

```text
staged verified Release bundle at /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app
```

## Install

Exact command invoked by the controller only after stage exited zero:

```sh
script/build_and_run.sh --install-staged-release-no-launch
```

Observed result: exit code `0`. The output verified the staged, temporary, and
promoted bundles and ended with:

```text
installed verified staged Release bundle at /Applications/ReleaseRadar.app
```

## Execution boundary

- No `run`, `debug`, `logs`, `telemetry`, or `verify` launch mode was invoked.
- No `open`, `pkill`, app executable, database command, or Keychain command was
  invoked by the controller during these two operations.
- A read-only post-install `pgrep` found no ReleaseRadar process.
- A read-only residue check found no `.ReleaseRadar.stage.*`,
  `.ReleaseRadar.install.*`, `.ReleaseRadar.backup.*`, or
  `.ReleaseRadar.failed.*` path under the two final parents.
- This evidence attests only to the commands observed in this controller
  session. Artifact QA/Security must separately verify the bundles and must not
  treat this as owner runtime validation.
