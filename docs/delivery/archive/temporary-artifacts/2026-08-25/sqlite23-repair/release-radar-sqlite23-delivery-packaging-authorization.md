# Delivery Packaging Authorization — SQLite-23 Repair

**Decision: AUTHORIZED, conditionally and in the exact order below.**  
**Open Required blockers: 0.**

This is a read-only Delivery authorization decision. It does not run either command, stage or install an artifact, launch or terminate the app, access owner data, change Git, or change the delivery ledger. It does not authorize Done, Accepted, or Ready for owner validation.

## Gate basis

All required pre-packaging roles are clean:

- Architecture: **GO**, Required 0, no ADR change (`/tmp/release-radar-sqlite23-arch-engineering-review.md`).
- TPM: **GO**, Required blockers 0 (`/tmp/release-radar-sqlite23-tpm-engineering-review.md`).
- Code re-review fix 1, QA re-review fix 2, and Security/Privacy re-review fix 1: each reports **0 Required**.
- The delivery ledger records the final four-file integrity values and no prior package/install/launch.
- Freshly rechecked in this decision: all four SHA-256 values match the ledger; scoped `git diff --check` and `bash -n script/build_and_run.sh` pass.
- The owner has expressly authorized the two required durable destinations and identical-bundle installation.

Unrelated existing working-tree changes are excluded. This authorization covers only the reviewed four-file repair and the two commands below.

## Authorized execution sequence

1. **Authorize exactly:**

   ```sh
   script/build_and_run.sh --stage-release-no-launch
   ```

   It is authorized to build Release only with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, verify the candidate, and atomically stage the verified bundle at:

   ```text
   /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app
   ```

   The stage operation must apply the reviewed strict/deep signing, configured authority/team, Hardened Runtime, exact main/Bridge entitlement, embedded-code, identifier/version/build, CDHash, executable-hash, resource-manifest, identity, and promotion/rollback checks. It must not launch, terminate, open, inspect owner data, or use Debug.

2. **Hard gate before installation:** proceed only if command 1 exits zero and produces retained evidence that the staged final exists at the durable `dist` path, passed every verifier, and has the expected complete identity. On any failure, stop; do not install, launch, retry through a different mode, or bypass the script's rollback result.

3. **Authorize only after that success gate:**

   ```sh
   script/build_and_run.sh --install-staged-release-no-launch
   ```

   It is authorized to verify the existing staged bundle (without building), copy to a unique `/Applications` sibling, verify/compare its identity, and atomically promote the identical verified bundle to:

   ```text
   /Applications/ReleaseRadar.app
   ```

   The staged `dist/ReleaseRadar.app` artifact must be preserved during installation. The install operation must not launch, terminate, open, inspect owner data, build a replacement, or use a Debug artifact. Any verification, identity, promotion, or restoration failure is terminal for this authorization: return nonzero, preserve/report the script-defined failed/backup artifacts, and stop.

## Mandatory post-execution gates

After a successful command 2, obtain fresh independent QA and Security/Privacy verification of the actual `dist` and `/Applications` bundles. Their evidence must include both durable paths; the exact command/configuration outcomes; strict/deep signatures; configured authority/team; Hardened Runtime; exact entitlements including rejection of unexpected values; embedded-code verification; identifier/version/build; CDHash; executable SHA-256; signed-resource manifest; and equality of staged and installed identities. They must also confirm no launch/owner-data access and record any promotion/rollback outcome.

Only after those two artifact reviews are GO with zero Required findings may Delivery consider recording **Ready for owner validation**. That status is not granted by this authorization. The owner alone may test `/Applications/ReleaseRadar.app` and explicitly approve it; no engineering gate may mark the task Done or Accepted.

## Classification

- **Required:** 0 open before authorized execution.
- **Optional:** future schema-version diagnostic wording alignment; structured project/entity association for the existing prepare audit.
- **Out of scope:** UI/product work, migrations, legacy-schema removal, onboarding SQL, owner-data modification/recovery, Debug handoff, launch behavior, and owner acceptance.
