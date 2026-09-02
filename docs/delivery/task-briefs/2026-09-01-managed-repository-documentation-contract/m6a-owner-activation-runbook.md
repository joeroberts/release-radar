# M6A owner activation runbook — preparation draft

**Status: Initial preflight and broker recovery approved and executed;
live operations paused on an incomplete read-only inventory.**
The owner approved recommended defaults and initial steps 1–3, then explicitly
approved backup-first normal startup of the installed app to restore its broker,
graceful close, and resumed preflight. Protected copies are complete; captured
owner bytes remain unchanged. Inventory established schema 10 and saved
identities but failed before catalog validation. The focused M2A correction is independently accepted; the replacement
candidate must pass the actual signed-app check before later live mutations. Steps 4–7, including
selected-root deployment, still require exact live approval. The owner now
requires delivery of M6A followed by a session stop before M6B.

This supporting procedure accompanies the [M6A brief](m6a-owner-activation-inventory-brief.md).
Exact owner locations, inventory, requests, custody, and approvals belong in
the owner-approved protected companion. Current delivery state remains in
[progress.md](../../progress.md).

## Frozen candidate

`MDCP-COMPAT-2` is the accepted M2A authorized-root search-access correction
on `codex/managed-documentation-contract-planning`; record its exact pushed
commit in the protected companion before resuming live execution. It replaces
`MDCP-COMPAT-1` (`dd32d8d0d7f333afc7367e5f2cc505d9e889c8cf`).
The correction changes only root-directory acquisition and its regression;
accepted storage, command, catalog, guidance, and signing contracts remain fixed.

The verified Release candidate is version **0.1.6**, build **1**, signed by
team **2UA854NLX4** with the existing entitlements and hardened runtime.
Paths below are relative to `ReleaseRadar.app`.

| Executable | Signing identifier | CDHash |
| --- | --- | --- |
| `Contents/MacOS/ReleaseRadar` | `com.rekonlabs.ReleaseRadar` | `9cd6d59d42efe263e2fa757b1fcb965a0adb3782` |
| `Contents/Helpers/ReleaseRadarAgentTools` | `com.rekonlabs.ReleaseRadarAgentTools` | `7cf24e3f613a3ec9fe2f4e48c2df80deeb6f4c5a` |
| `Contents/Resources/ReleaseRadarBridgeAgent` | `com.rekonlabs.ReleaseRadarBridgeAgent` | `cb9d4531f918781637b887c9756925062d1d7005` |
| `Contents/Resources/ReleaseRadarPluginLifecycleHelper` | `com.rekonlabs.ReleaseRadarPluginLifecycleHelper` | `d7c796987ac69d8fab6f3c0f21c016d2c803fad1` |

- App executable SHA-256:
  `34795c4b8fbc6ee048a06070cab8683a1816848ca7b46f6e2621ca66c320cf78`.
- App `Contents/_CodeSignature/CodeResources` SHA-256:
  `8bf66fd75186f4548c297e883a716255eba7cfcb3227740309ddc0ce5675d8ec`.
- Bundled plugin **0.1.6** normalized digest:
  `dad143d88e77af7e2ed4523c17c31a24fdd8810e87d02a2ccfe2c39ba5558f8c`.
- Packaged agent tool exposes the accepted **19** tool schemas. Safe
  initialize/tools-list and strict signature verification already passed.

Verified app and documentation-checker copies are retained as temporary build
outputs under `.build/mdcp-compat-2/`. The checker requires its adjacent
`ReleaseRadarCore.framework`. The replacement has not been installed or launched against owner state.
The prior candidate was launched once in explicit read-only maintenance against
the approved existing owner store, then closed.
Revalidate the selected bundle before approving its installation;
a rebuilt or changed bundle needs a newly recorded exact identity.

## Inputs required before live approval

The protected companion must name:

1. Existing owner project and canonical repository folder; exact persisted
   project ID and root-row ID, established through approved supported readback.
   The development worktree is not assumed to be that root. The handoff prompt
   and current Codex task root must meet the shipped skill's exact-root rule.
2. Existing database path and schema, installed app/helper/plugin identities,
   installation destination, verified Codex CLI path, existing broker state,
   and the exact processes/clients whose quiescence is required. Discovery
   requiring owner access needs its own bounded approval if these are unknown.
3. Protected backup parent and companion location, an app-writable disposable
   restore location, ownership/access restrictions, restoration custodian,
   retention deadline through acceptance, and explicit disposal terms for
   both copies. A store-path argument does not grant sandbox access.
4. Exact repository candidate at the selected owner root: unchanged document
   paths, valid catalog and generated indexes, existing catalogued progress
   ledger, repository ID, version, canonical digest, and snapshot. The staged
   development catalog has repository ID
   `e7475429-ef51-4368-ad9e-61d9073d5a4f`; that is not proof of the live target.
5. Exact permitted installation/plugin workflow, migration and test launches,
   guidance-only diff, handoff evidence identity, complete mutation requests,
   binding target, replay/readback actions, recovery actions, and expected
   state differences. Broker registration or repair is not implicit.

No placeholder authorizes target inference. Do not request approval to mutate
an unidentified project, database, root, or backup location.

When persisted IDs are unknown, first obtain approval for the named repository,
expected existing store/software locations, protected locations and retention
terms, and **only steps 1–3** below. That bounded preflight confirms metadata,
quiesces approved writers, protects the existing database set, and reads the
exact IDs and baseline without migration or installation. A location, identity,
permission, schema, or broker mismatch stops instead of selecting another
target. Keep writers closed afterward and complete the protected companion
with those results before requesting approval for steps 4–7 and recovery.
The owner has approved the recommended target/protected-location/retention
defaults for that initial preflight. The protected companion and separate pre-/post-recovery backups are complete.
Read-only typed discovery established the exact saved project/root identities,
schema 10, seven legacy path records, and no binding. Inventory remains
incomplete pending the reader investigation; no migration has occurred.

## Broker recovery — authorized and completed

Read-only background-task metadata reports the bridge item as disabled and
allowed, with its parent associated with a temporary Debug bundle rather than
the verified installed app. This is not evidence that merely enabling the
existing item would restore the correct installation. Do not enable the stale
item, unregister services, bootstrap a replacement manually, or introduce a
registration harness.

The existing supported registration route is normal startup of the installed
0.1.5 app. Independent source review confirms that normal startup also opens
owner storage, starts notification recovery/delivery, and can run plugin
lifecycle work before or alongside bridge registration. Maintenance cannot
perform registration by itself. Those normal-startup effects received the owner's separate explicit approval.

Executed bounded recovery: under the approved quiescence and custody terms,
preserve the complete existing database/recovery set and necessary software
state before starting the installed app; launch that exact app normally to
restore its broker; verify the resulting registration/signing identity; close
the app and verify process exit; then repeat the approved initial preflight
against the correct broker. Keep the pre-recovery backup separate from any
post-recovery baseline and record normal-startup changes explicitly. An
unchanged, unavailable, or conflicting registration stops this recovery.
The exact installed broker was restored and verified. The app and lifecycle
writer exited. Pre- and post-recovery copies contain identical file bytes. No
candidate installation, direct database repair, or notification suppression
workaround occurred.

## Plugin installation limitation

The frozen maintenance host has no plugin lifecycle action. The supported
Codex CLI can install the bundled plugin while the ordinary app is closed, but
that external installation does not update the app's managed lifecycle
receipt. The app can consequently report Modified/Needs repair despite exact
installed plugin bytes. Its managed receipt update uses the normal app
lifecycle coordinator, whose startup also enables unrelated writers.

The proposed owner-approved choice is the supported external CLI install:
verify exact installed identity/version/digest and enabled configuration,
preserve the old receipt, and record "exact plugin installed; managed receipt
unchanged; repair deferred." The frozen documentation command boundary does
not require that receipt to be current. Its digest mismatch prevents automatic
managed update and offers explicit Reinstall; any such repair remains separate
work after controlled acceptance and owner release. Do not call the external
install a successful managed lifecycle update, silently start normal services,
edit the receipt, bypass helper authentication, or add a maintenance feature
inside M6A. This proposed choice still needs exact live authorization.

The fixed supported CLI sequence is `plugin marketplace add <verified bundled
marketplace> --json` only when that marketplace is absent, then `plugin add
release-radar@release-radar --json`. An existing marketplace must resolve to
the exact selected installed bundle's marketplace; a conflict stops. Resolve
the verified CLI executable and marketplace path in the protected companion
before approval. Do not invoke the lifecycle helper through an unauthenticated
external client or treat CLI exit status alone as installation verification.

## Ordered live procedure, after exact approval

Every maintenance-host/store transition requires quitting the current host and
verifying process exit before launching the next explicit store override. Do
not rely on launch arguments being delivered to an already-running instance.

1. **Confirm and quiesce.** Recheck candidate signatures, exact target identities,
   repository state, broker availability, and approved process identities.
   Gracefully close every owner-store writer and mutation-capable client;
   verify their exit. Keep normal app startup disabled. The existing build/run
   script is not a standalone quiescence command and must not be invoked for
   preflight: its install/run paths also replace or launch software.
2. **Protect the complete existing state.** Under continuing quiescence, inspect
   no-follow metadata for the exact main database and `-wal`, `-shm`, and
   `-journal` sidecars. Reject symlinks/nonregular files, any journal, or a
   nonempty WAL. A residual WAL requires supported graceful shutdown/recovery;
   never delete sidecars or run SQL to make preflight pass. Copy the main file
   and every present permitted sidecar together into the approved protected
   directory; record absence of missing sidecars. Also inventory the exact
   adjacent `<database>.pre-migration` snapshot: record presence/absence,
   require a regular no-follow file if present, and preserve its exact bytes
   in the protected backup map with retention/restoration terms. Approved
   migration may replace this snapshot; that replacement must be explicit in
   the live authorization. Use directory access 0700
   and file access 0600 for the approved custodian, verify byte equality and
   stable source metadata, and retain the originals unchanged. Preserve exact
   existing app/plugin/configuration and guidance bytes needed by the approved
   rollback. These are owner backups, not generic disposable build outputs.
3. **Read the unmigrated baseline.** Use the exact candidate in
   `--documentation-maintenance=read-only` mode with an explicit
   `--documentation-maintenance-store=<approved existing database>` argument.
   The existing enabled authenticated broker is required for typed inventory;
   maintenance never installs or repairs it. Call
   `release_radar_inventory_evidence` through the verified frozen candidate's
   `Contents/Helpers/ReleaseRadarAgentTools` STDIO client, including during the
   disposable-copy checks before installation. Do not use the old plugin's
   hard-coded installed-app path or assume it exposes the new inventory tool.
   Query the authorized root; optional IDs are
   for approved discovery only, then require exact project/root IDs. Recognized
   schemas 10–13 are supported without creation, migration, or repair. Keep
   full results in the protected companion, then close the host and verify
   unchanged database/sidecar bytes. Missing/stale bookmark, identity mismatch,
   schema refusal, or unavailable/oversized inventory stops this procedure.
4. **Prove disposable restoration and migration.** Copy the protected backup
   set to the distinct approved app-writable restore location and verify exact
   bytes. Run read-only preflight on that copy, then close the host. Launch the
   candidate with `--documentation-maintenance=commands` and the explicit
   disposable-store override; send no mutation command. Normal app migration
   runs on this copy only. Inspect the immediate typed migration result, close,
   and relaunch the copy in read-only mode. Never omit the override on a copy
   launch. Compare against the baseline as described below. Restore the copy
   again from the backup and prove supported readback of the original schema
   and state. The app's adjacent `.pre-migration` snapshot, made by
   `VACUUM INTO`, is additional migration recovery, not the protected backup.
5. **Install and migrate the owner target.** Only after the disposable proof,
   follow the exact separately approved app/plugin installation workflow.
   Revalidate installed identities and launch only commands maintenance on the
   exact owner store. Read back immediately, before handoff or binding; require
   schema 13, no inferred binding, and preserved legacy evidence/unrelated
   state. Close and relaunch read-only to prove persistence. Any unexpected
   difference selects the approved recovery path before further mutation.
6. **Perform the exact v2 handoff.** Obtain complete pre-upgrade inventory while
   guidance is legacy/v1. Follow the frozen bundled skill and exact owner
   prompt. Validate no-follow paths and the catalog/index/ledger prerequisites.
   Reuse the sole exact ticketless legacy root-`AGENTS.md` evidence row with
   the stable `release-radar-handoff:v1:` prefix, or generate a new prefixed ID
   only when inventory proves none exists. Ambiguity stops. Append/replace
   only the permitted managed block and preserve all other guidance bytes and
   the entire progress ledger. Read the files back, then submit the approved
   `release_radar_add_evidence` request through commands maintenance, with
   `ticketID` omitted and a fresh request UUID. Preserve that complete request
   and its audited result for exact replay. Already-v2/unbound recovery needs
   a separately approved binding-first sequence; do not improvise the upgrade.
7. **Bind, replay, and relaunch.** Submit the approved
   `release_radar_bind_documentation_repository` request naming exact project,
   root row, repository ID, catalog version/digest, and request UUID. Replay the
   complete same request and require the same receipt/result without another
   audit. After closing commands maintenance, relaunch read-only on the exact
   owner store. Require persisted accepted binding/snapshot, current v2
   guidance, complete inventory, and unchanged pre-existing legacy locators.
   Keep ordinary writers quiesced. Prepare the reconciliation proposal from
   this inventory, deliver M6A and its handoff, then stop for a new session.
   Do not open M6B, adopt evidence, or move documents in this session.

## Equality and recovery

Compare stored evidence IDs, project/ticket associations, locator and stored
availability; exact root/bookmark fingerprints; all preservation domains
available in the source schema; and existing audit/receipt fingerprints.
Immediate migration equality precedes handoff/binding and establishes the v13
baseline for subsequent comparisons. New schema domains have only the expected
migration state. Later differences are limited to the approved handoff row,
binding, exact new audit/receipt identities, and explicitly approved plugin
lifecycle state. Existing records must remain unchanged. Do not infer state
preservation from a successful process exit or from UI appearance alone.

Inventory may expose stored preservation metadata with `isComplete=false`
when v2 is unbound; that can support the migration comparison but cannot
establish completed inventory or adoption eligibility. Final M6A readback
requires `isComplete=true`. Evidence queries are bounded at 4,096 rows, other
queries at 10,000 rows, and the encoded reply at 131,072 bytes; refusal is not
permission to split or omit data.

For `outcomeUnknown`, retain quiescence and replay the complete original
request before choosing recovery. Never invent another request or restore
over an uncertain committed operation. Migration/corruption/unexpected-state
recovery closes all writers and restores the exact approved database set,
including the prior `.pre-migration` snapshot's approved presence/absence,
software/configuration, and guidance together, then proves supported readback
against the preserved baseline. Quarantine failed state only at an approved
protected location. Do not delete backups, disposable restores, or migration
snapshots without the specific approved retention/disposal terms.

M6A completion needs independent QA, Architecture, and Security/Privacy review
of the actual authorized operations and readback. Record only concise outcomes,
approvals, comparisons, and remaining risks in the public progress ledger;
owner paths, bookmark bytes, evidence content, and backup locations stay in the
protected companion. M6B and ordinary live-use release remain separately gated.
