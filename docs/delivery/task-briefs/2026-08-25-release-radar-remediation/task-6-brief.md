### Task 6: Ship a deterministic production macOS AppIcon in the approved V1 direction

**Planning gate:** GO, once TPM and Delivery Management confirm the prior serialized writer is accepted and release RR-R6. No product or architecture decision is blocked: the owner-approved V1 icon direction already controls this task, and RR-R6 changes only static resources and app-target wiring.

**Objective / user-visible outcome:** The signed Release Radar app uses a production AppIcon that preserves the approved deep graphite-navy segmented orbit, five work tiles, one cyan active tile, and restrained violet-to-cyan scan. Finder, Dock, and the standard About panel show the same recognizable identity, including at small system sizes, instead of the generic application icon.

**Controlling references:** `docs/brand/README.md`; `docs/brand/release-radar-icon-v1.png`; `docs/design/mockups/icon.png`; the icon portion of `docs/design/mockups/full_logo.png`; `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` Task 6; `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` signed-app/product-identity constraints; and `docs/architecture/ADR-001-release-radar-boundaries.md` sandbox/signing boundary.

The reference identities inspected before implementation are:

- `docs/brand/release-radar-icon-v1.png`: 1254 × 1254 RGB PNG, SHA-256 `b94fb5b029dd262cfb9e196efdf089fb3d72aee76d433ebfd448cc26691f7ddd`.
- `docs/design/mockups/icon.png`: the byte-identical 1254 × 1254 RGB PNG with the same SHA-256; it is not an independent production source.
- `docs/design/mockups/full_logo.png`: 1968 × 799 RGB PNG, SHA-256 `cb7ba41ca0aeb58e7cbd1d680b4fca10d84facaaf38550a72b0f9105ed56ba78`; it confirms the icon/lockup relationship but its wordmark is out of scope.

If any controlling reference hash changes before implementation, stop and return the brief to Planning/Design review instead of silently producing against mixed references.

**Verified baseline:** The existing configured Debug app at `DerivedData/Build/Products/Debug/ReleaseRadar.app` has no `CFBundleIconFile`, no `Assets.car`, and no compiled icon resource. It is otherwise a valid Apple Development-signed `com.rekonlabs.ReleaseRadar` app for team `2UA854NLX4`, with hardened runtime and the existing sandbox, app-group, read-only user-selected-file, outbound-network, and Debug `get-task-allow` entitlements. RR-R6 must add the icon without repairing or changing any of those boundaries.

**In scope:** One deterministic SVG source; seven unique lossless PNG exports covering all ten required macOS 1x/2x AppIcon slots; `Contents.json`; one explicit `PBXFileReference`/`PBXBuildFile` that places `ReleaseRadar/Assets.xcassets` in only the app Resources phase; `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in only the Debug and Release app-target configurations; non-launching configured build inspection; and isolated signed visual QA.

**Out of scope:** Copying, resizing, tracing pixel data from, or bundling either generated raster reference; redesigning the approved icon direction; producing or changing the wordmark/lockup; app source changes beyond the exact Debug capture predicate/model guard below; test changes beyond one compact AppRoute regression; Info.plist source edits; entitlement/signing-identity/team changes; new dependencies or export scripts; production/default startup changes; generalized Keychain/coordinator protocols or capture infrastructure; persistence/audits; bridge behavior; folder access; owner data; release packaging; Developer ID; notarization; Gatekeeper distribution claims; or launching the owner bundle.

**Dependencies / release gate:** RR-R6 has no technical dependency on RR-R1 through RR-R5, but it remains last in the owner-priority serialized remediation sequence. TPM and Delivery Management must release one fresh Implementer only after the prior writer is accepted. No other writer may touch `ReleaseRadar.xcodeproj/project.pbxproj` or `ReleaseRadar/Assets.xcassets` concurrently.

**Files:**

- Create `docs/brand/release-radar-icon-v1.svg` as the sole editable production artwork source.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/Contents.json`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-64.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`.
- Create `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- Modify `ReleaseRadar.xcodeproj/project.pbxproj` only to add the explicit app-only asset-catalog file/build references, exclude `Assets.xcassets` from implicit synchronized membership, add that build file to the `ReleaseRadar` Resources phase, and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in the two `ReleaseRadar` app-target configurations.
- Modify `ReleaseRadar/App/ReleaseRadarApp.swift` only to derive/reuse the Debug capture external-service predicate and pass it to `AppModel`.
- Modify `ReleaseRadar/App/AppModel.swift` only to accept the predicate result and guard the two external-service calls during dashboard load.
- Modify `ReleaseRadarTests/AppRouteTests.swift` only for the compact launch-policy/coordinator regression.

The synchronized root did not compile the new catalog in pre-review. Use unused IDs `A10000000000000000000018` for the `folder.assetcatalog` `PBXFileReference` and `B10000000000000000000007` for its `PBXBuildFile`; add the file reference to the main group, add `Assets.xcassets` to exception set `A90000000000000000000001`, and add the build file only to app Resources phase `C10000000000000000000003`. Do not add it to Core, helper, bridge, or test Resources phases, and do not add `Info.plist` or `ReleaseRadar.entitlements` to resources.

**Deterministic artwork contract:** Hand-author the SVG as geometry; do not embed or link raster images, fonts, scripts, external styles, metadata generators, or remote resources. Use a transparent 1024 × 1024 canvas and simple SVG paths/rectangles/circles/linear gradients that `/usr/bin/sips` can rasterize locally. Preserve these bounded visual facts from the approved reference:

- A rounded-square background inset from the transparent canvas, filled deep graphite-navy (`#111832`) with a restrained darker edge (`#20294F`), not a white or opaque outer square.
- A segmented orbit centered at `(512, 512)` with an approximately 270-point radius, a violet/indigo stroke (`#7C5CFA`), rounded ends, and five visible gaps rather than a complete circle.
- Exactly five rounded work tiles distributed around the orbit. Inactive tiles use a visible indigo fill (`#2D2869`) and violet stroke (`#8365F7`); the upper-right tile is the single active tile and uses cyan fill/stroke (`#16CDE8` / `#47F2FF`).
- A center hub and a single restrained triangular/radial scan from the hub toward the active tile, using a violet-to-cyan linear gradient and partial opacity. The scan stays inside the background and does not obscure the active tile.
- No text. Avoid fine texture, blur, glow, or shadow details that disappear at 16–32 pixels. Geometry, stroke widths, and contrast may be simplified only to make this same direction legible; adding symbols, letters, extra tiles, a different palette, or a different composition is a redesign and is prohibited.

The Implementer records the final SVG SHA-256 and the exact palette/geometry values in the task report. Independent QA decides fidelity against the controlling reference; the Implementer does not self-approve its visual judgment.

**Exact source-to-PNG representation matrix:** Export each unique PNG once from the deterministic SVG. Reuse the same 32, 256, and 512-pixel files in the two catalog slots that require the same physical dimensions.

| macOS logical size | scale | physical pixels | catalog filename |
| --- | --- | --- | --- |
| 16 × 16 | 1x | 16 × 16 | `AppIcon-16.png` |
| 16 × 16 | 2x | 32 × 32 | `AppIcon-32.png` |
| 32 × 32 | 1x | 32 × 32 | `AppIcon-32.png` |
| 32 × 32 | 2x | 64 × 64 | `AppIcon-64.png` |
| 128 × 128 | 1x | 128 × 128 | `AppIcon-128.png` |
| 128 × 128 | 2x | 256 × 256 | `AppIcon-256.png` |
| 256 × 256 | 1x | 256 × 256 | `AppIcon-256.png` |
| 256 × 256 | 2x | 512 × 512 | `AppIcon-512.png` |
| 512 × 512 | 1x | 512 × 512 | `AppIcon-512.png` |
| 512 × 512 | 2x | 1024 × 1024 | `AppIcon-1024.png` |

`Contents.json` must declare those ten rows with `idiom: "mac"`, the exact logical `size`, exact `scale`, and exact filename, plus `info.author = "xcode"` and `info.version = 1`. Do not add universal/iOS/marketing slots or unattached images.

**Provenance / reproducibility:** Use the repository SVG as the only export input and the platform-bundled `/usr/bin/sips`; do not add a renderer dependency. From the repository root, run the equivalent of the following for all seven physical sizes:

```sh
for pixels in 16 32 64 128 256 512 1024; do
  /usr/bin/sips \
    -s format png \
    -z "$pixels" "$pixels" \
    docs/brand/release-radar-icon-v1.svg \
    --out "ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-$pixels.png"
done
```

Record `sw_vers -productVersion`, `xcodebuild -version`, and SHA-256 values for the SVG and seven PNG exports. The committed files are the reproducible build inputs; no generator script is needed for this bounded one-source export.

**Debug live-QA isolation interface:** Add `AppLaunchConfiguration.externalServicesSuppressed(arguments:isDebugBuild:) -> Bool`, true only when `isDebugBuild` and arguments contain `--rr10-capture`. Reuse it for the existing AppDelegate capture guard and pass it as `AppModel(externalServicesSuppressed:)`, whose default is `false`. In `loadDashboard()`, when true skip only `loadPushoverConfiguration()` and `notificationCoordinator.dispatchPending()`; dashboard/store/UI loading remains unchanged. Ordinary Debug, Release, and tests without explicit suppression preserve current behavior.

**Data / persistence / security / privacy:** Security re-review established that traditional macOS Keychain lookup is not isolated merely by the alternate application identifier when `kSecAttrAccessGroup` is omitted. Live QA therefore relies on the narrow Debug-only suppression above to prevent Pushover lookup and pending delivery; the alternate container and empty notification database remain additional owner-data boundaries, not the Keychain control. Do not change Keychain code, notification code/coordinator APIs, or any other product source. Preserve `ReleaseRadar/Info.plist`, `ReleaseRadar/ReleaseRadar.entitlements`, owner bundle identifier `com.rekonlabs.ReleaseRadar`, team `2UA854NLX4`, manual Apple Development signing, App Sandbox, and Hardened Runtime. Debug `get-task-allow` remains a build-injected development entitlement and is not a distribution claim.

**Compact regression:** Extend the existing launch-policy test to assert suppression is true for Debug + `--rr10-capture` (with or without `--rr10-empty-store`) and false for ordinary Debug, non-Debug capture, and non-Debug ordinary arguments. With the existing concrete `AppNotificationCoordinator`/store fixture, queue one event, call `loadDashboard()` on a model with `externalServicesSuppressed: true`, and assert event state/attempt count remain untouched. Do not add a Keychain spy or generalize collaborator protocols; the single branch plus coordinator/store observation is sufficient.

#### Artifact-first implementation and verification sequence

- [ ] **1. Capture RED at the launch and bundle boundaries.** First add the compact `AppRouteTests` regression above and run `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/AppRouteTests`; expect failure because the external-service predicate/model input does not exist. Then use a fresh temporary derived-data directory, build without launching, and keep output outside the repository:

  ```sh
  RR6_RED_DD="$(mktemp -d /tmp/release-radar-rr-r6-red.XXXXXX)"
  xcodebuild \
    -project ReleaseRadar.xcodeproj \
    -scheme ReleaseRadar \
    -configuration Debug \
    -derivedDataPath "$RR6_RED_DD" \
    clean build
  RR6_RED_APP="$RR6_RED_DD/Build/Products/Debug/ReleaseRadar.app"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$RR6_RED_APP/Contents/Info.plist"
  test -f "$RR6_RED_APP/Contents/Resources/AppIcon.icns"
  test -f "$RR6_RED_APP/Contents/Resources/Assets.car"
  ```

  Expected before RR-R6: the launch regression fails; the configured build may succeed, then the icon assertions fail because the key/resources do not exist. These are the only regression seams; do not add a screenshot-test harness or generalized service-spy infrastructure.

- [ ] **2. Create the deterministic source, seven PNGs, and exact catalog metadata.** Author the SVG under the artwork contract, export with the exact command above, and write only the ten-row macOS `Contents.json`. Verify the source matrix before touching project wiring:

  ```sh
  plutil -lint ReleaseRadar/Assets.xcassets/AppIcon.appiconset/Contents.json
  for pixels in 16 32 64 128 256 512 1024; do
    file="ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-$pixels.png"
    test "$(/usr/bin/sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')" = "$pixels"
    test "$(/usr/bin/sips -g pixelHeight "$file" | awk '/pixelHeight/{print $2}')" = "$pixels"
    /usr/bin/file "$file" | /usr/bin/grep -q 'PNG image data'
  done
  ```

  Inspect all seven exports at actual size and enlarged nearest-neighbor view. The 16/32-pixel versions must retain a recognizable rounded navy tile/orbit silhouette and a distinct cyan active tile without white fringe or clipping; larger versions must retain all five tiles, segmented orbit, hub, and restrained scan.

- [ ] **3. Wire the catalog explicitly and only to the app.** Add file reference `A10000000000000000000018` (`lastKnownFileType = folder.assetcatalog`, `path = ReleaseRadar/Assets.xcassets`, `sourceTree = SOURCE_ROOT`) to the main group; add build file `B10000000000000000000007`; add `Assets.xcassets` to synchronized-root exception set `A90000000000000000000001`; and add that build file only to app Resources phase `C10000000000000000000003`. Add `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` to app build configurations `A50000000000000000000053` (Debug) and `A50000000000000000000054` (Release). Do not alter project-level signing, deployment, Info.plist, helper targets, or test targets. Assert the exact PBX scope, then confirm both resolved app configurations report the setting:

  ```sh
  plutil -convert json -o - ReleaseRadar.xcodeproj/project.pbxproj \
    | /opt/homebrew/bin/jq -e '
      .objects["A10000000000000000000018"].isa == "PBXFileReference" and
      .objects["A10000000000000000000018"].lastKnownFileType == "folder.assetcatalog" and
      .objects["A10000000000000000000018"].path == "ReleaseRadar/Assets.xcassets" and
      .objects["B10000000000000000000007"].fileRef == "A10000000000000000000018" and
      (.objects["A90000000000000000000001"].membershipExceptions | index("Assets.xcassets")) != null and
      (.objects["C10000000000000000000003"].files | index("B10000000000000000000007")) != null and
      ([.objects | to_entries[] | select(.value.isa == "PBXResourcesBuildPhase" and .key != "C10000000000000000000003") | .value.files[]?] | index("B10000000000000000000007")) == null and
      .objects["A50000000000000000000053"].buildSettings.ASSETCATALOG_COMPILER_APPICON_NAME == "AppIcon" and
      .objects["A50000000000000000000054"].buildSettings.ASSETCATALOG_COMPILER_APPICON_NAME == "AppIcon" and
      ([.objects | to_entries[] | select(.value.isa == "XCBuildConfiguration" and (.key != "A50000000000000000000053" and .key != "A50000000000000000000054")) | .value.buildSettings.ASSETCATALOG_COMPILER_APPICON_NAME? | select(. != null)] | length) == 0
    '

  for configuration in Debug Release; do
    xcodebuild \
      -project ReleaseRadar.xcodeproj \
      -scheme ReleaseRadar \
      -configuration "$configuration" \
      -showBuildSettings \
      | /usr/bin/grep -q 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon'
  done
  ```

- [ ] **4. Run GREEN on a fresh configured, non-launching build.** Build to a new temporary derived-data directory using the ordinary app identity and configured signing. Then verify Info.plist, compiled catalog, compiled icon, all extracted `.icns` slots, absence of reference rasters, and strict signing:

  ```sh
  RR6_GREEN_DD="$(mktemp -d /tmp/release-radar-rr-r6-green.XXXXXX)"
  xcodebuild \
    -project ReleaseRadar.xcodeproj \
    -scheme ReleaseRadar \
    -configuration Debug \
    -derivedDataPath "$RR6_GREEN_DD" \
    clean build
  RR6_GREEN_APP="$RR6_GREEN_DD/Build/Products/Debug/ReleaseRadar.app"
  RR6_ICONSET="$RR6_GREEN_DD/AppIcon.iconset"

  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$RR6_GREEN_APP/Contents/Info.plist")" = 'AppIcon'
  test -f "$RR6_GREEN_APP/Contents/Resources/Assets.car"
  test -f "$RR6_GREEN_APP/Contents/Resources/AppIcon.icns"
  /usr/bin/assetutil --info "$RR6_GREEN_APP/Contents/Resources/Assets.car" > "$RR6_GREEN_DD/assetutil-info.json"
  RR6_CAR_TUPLES="$(/opt/homebrew/bin/jq -er '
    [.[] | select(.AssetType == "Icon Image" and .Name == "AppIcon")]
    | if length == 10 then . else error("expected exactly 10 AppIcon Icon Image renditions") end
    | sort_by(.PixelWidth, .Scale)
    | .[]
    | [.RenditionName, (.Scale | tostring), (.PixelWidth | tostring), (.PixelHeight | tostring)]
    | join("|")
  ' "$RR6_GREEN_DD/assetutil-info.json")"
  RR6_EXPECTED_CAR_TUPLES=$'AppIcon-16.png|1|16|16\nAppIcon-32.png|1|32|32\nAppIcon-32.png|2|32|32\nAppIcon-64.png|2|64|64\nAppIcon-128.png|1|128|128\nAppIcon-256.png|1|256|256\nAppIcon-256.png|2|256|256\nAppIcon-512.png|1|512|512\nAppIcon-512.png|2|512|512\nAppIcon-1024.png|2|1024|1024'
  test "$RR6_CAR_TUPLES" = "$RR6_EXPECTED_CAR_TUPLES"
  /usr/bin/iconutil --convert iconset --output "$RR6_ICONSET" "$RR6_GREEN_APP/Contents/Resources/AppIcon.icns"
  test -d "$RR6_ICONSET"
  ```

  The filtered CAR assertion deliberately excludes the `MultiSized Image` summary rendition and compares the seven source filenames to exactly ten compiled `Icon Image` tuples, including the three reused physical files at their two required scales. `AppIcon.icns` existence and successful `iconutil` parsing are smoke checks only; do not reject a valid modern catalog because `iconutil` coalesces representations instead of extracting ten files. A passing source-dimension check alone remains insufficient.

  Also require:

  ```sh
  ! /usr/bin/find "$RR6_GREEN_APP/Contents/Resources" -type f \
    | /usr/bin/grep -E 'release-radar-icon-v1\.png|full_logo\.png|docs/design/mockups'
  /usr/bin/codesign --verify --deep --strict --verbose=4 "$RR6_GREEN_APP"
  /usr/bin/codesign -dvvv --entitlements :- "$RR6_GREEN_APP" > "$RR6_GREEN_DD/codesign.txt" 2>&1
  /usr/bin/grep -q 'Identifier=com.rekonlabs.ReleaseRadar' "$RR6_GREEN_DD/codesign.txt"
  /usr/bin/grep -q 'TeamIdentifier=2UA854NLX4' "$RR6_GREEN_DD/codesign.txt"
  /usr/bin/grep -q 'Authority=Apple Development: jaroberts4@gmail.com (PT7GS96H3L)' "$RR6_GREEN_DD/codesign.txt"
  /usr/bin/grep -q 'flags=0x10000(runtime)' "$RR6_GREEN_DD/codesign.txt"
  git diff --exit-code -- ReleaseRadar/Info.plist ReleaseRadar/ReleaseRadar.entitlements
  git diff --check -- ReleaseRadar.xcodeproj/project.pbxproj docs/brand/release-radar-icon-v1.svg ReleaseRadar/Assets.xcassets
  ```

  Security/Privacy must independently inspect the effective entitlements and nested-code strict verification. `spctl`/notarization is intentionally excluded: this remains a local Apple Development build, not a Developer ID/notarized distributable.

- [ ] **5. Run GREEN and perform isolated live visual QA with Computer Use.** Re-run the focused `AppRouteTests` command and require the Debug-capture matrix plus untouched queued-event assertion to pass. Build a separate fresh app with `PRODUCT_BUNDLE_IDENTIFIER=com.rekonlabs.ReleaseRadar.RR6QA` into a temporary derived-data directory and use a never-before-used alternate container. Before launch, verify Info.plist and `codesign -dvvv` identify `com.rekonlabs.ReleaseRadar.RR6QA` and team `2UA854NLX4`, and run strict deep codesign. The alternate identifier is container/signing evidence only and must not be claimed as traditional Keychain isolation. Launch only that bundle with the existing `--rr10-capture --rr10-empty-store` arguments and confirm the Debug-only suppression predicate is active.

  Confirm the exact alternate container is absent before its first initialization launch. Initialize it once in suppressed capture mode, quit, and before the visual relaunch inspect only that isolated database read-only: `SELECT COUNT(*) FROM notification_events` and `SELECT COUNT(*) FROM notification_occurrences` must both return zero. Suppressed capture must perform neither `loadPushoverConfiguration()` nor `dispatchPending()`, so no traditional Keychain lookup or notification delivery occurs. Use Finder `open -R` to reveal the alternate `.app`, then Computer Use to inspect Finder, Dock, and the app's standard `About Release Radar By Rekon Labs` panel. Quit after capture. Never launch `com.rekonlabs.ReleaseRadar`, inspect its Keychain items, inspect/modify its Application Support database, grant folder access, or send a notification.

#### Exact visual QA checklist

- [ ] **Reference fidelity:** Rounded graphite-navy tile, five work tiles, segmented violet orbit, center hub, one upper-right cyan active tile, and its restrained violet-to-cyan scan read as the same V1 direction. No wordmark, letters, extra tile, alternate palette, or generated-raster artifact appears.
- [ ] **Finder:** The alternate app shows the production identity rather than a generic icon in list view and icon view. Check nominal 16, 32, 64, 128, 256, and 512-point Finder sizes through View Options; no transparent-edge fringe, clipping, unintended white square, blur, or disappearing active tile.
- [ ] **Dock:** With the isolated app running, the Dock shows the same identity at normal and magnified size; the cyan tile remains distinct and the outer rounded-square silhouette does not collapse into the background.
- [ ] **About:** `About Release Radar By Rekon Labs` displays the AppIcon and existing application name/version text. The icon is not stretched, cropped, or replaced with the generic executable icon.
- [ ] **Export/compiled parity:** Compare the seven source PNGs to the exact ten filtered CAR `Icon Image` tuples. At 16/32 pixels, the overall orbit/tile cue and active cyan tile remain recognizable; at 64 pixels and above, all five tiles, segmented orbit, hub, and scan remain distinct. Duplicate-dimension slot pairs intentionally map the same physical source filename at different scales.
- [ ] **Isolation:** No folder chooser is used, no folder access is granted, no sample data is seeded, no Pushover Keychain lookup occurs, and no notification is delivered. The Debug-only predicate is true, isolated notification tables are empty before visual relaunch, and the owner bundle, credential items, container, and database remain untouched. Normal Debug and Release startup remain unsuppressed.

**Happy path:** Xcode compiles the explicitly app-resource-wired catalog, writes `CFBundleIconFile = AppIcon`, packages the exact ten CAR `Icon Image` representations, and preserves the existing signature/entitlements. Debug capture alone skips Pushover configuration and pending dispatch; Finder, Dock, and About display the approved identity from the signed alternate bundle without owner credential access or notification delivery.

**Non-happy path / failure behavior:** A malformed catalog, missing slot, failed SVG export, wrong pixel dimension, absent `CFBundleIconFile`, missing/invalid `Assets.car` or `AppIcon.icns`, failed strict code signature, signing/entitlement drift, bundled reference raster, or visual loss of the icon at small sizes rejects RR-R6. Correct the deterministic SVG or catalog and rerun the same bounded checks; do not fall back to the generated raster, change signing/entitlements, add a dependency, launch the owner app, or claim notarization.

**Activity / audit evidence:** None. Static build assets and read-only presentation create no product activity or audit event. The durable ledger records provenance hashes, resource RED/GREEN, resolved build settings, Info.plist/assetutil/iconutil evidence, strict signing/effective entitlements, isolated visual captures, and independent decisions—not an application audit.

**Acceptance criteria:** The catalog is explicitly referenced only by the app Resources phase and the configured signed app selects `AppIcon`; the exact ten filtered CAR `Icon Image` tuples map to the seven deterministic SVG-derived PNGs while `AppIcon.icns` parses as a smoke check; Finder, Dock, and About show a legible approved V1 identity; generated raster references are absent from the bundle; `Info.plist` source, entitlements, owner bundle identity, signing identity/team, sandbox, and hardened runtime are unchanged; only Debug capture suppresses Pushover configuration/pending dispatch, normal and production behavior remain unchanged, isolated notification state is empty with no Keychain lookup or delivery, no owner runtime/data is touched, and no distribution/notarization claim is made.

**Required independent reviews:** Code Reviewer for asset/project scope and catalog correctness; QA for artifact matrix, Computer Use visual fidelity, Finder/Dock/About, and isolation; Architect for synchronized-resource and no-runtime-boundary effects; Security/Privacy for signing identity, strict nested verification, effective entitlement preservation, and no owner-data access; TPM for scope/gate; and Delivery Manager for durable evidence and milestone closure. The Implementer may not perform any of those independent approvals.

**Completion evidence:** Record RR-R6 release gate and assigned fresh role; reference/SVG/PNG SHA-256 values and tool versions; launch-policy/coordinator RED/GREEN plus normal-path preservation; icon RED assertions; exact app-only PBX resource scope; catalog and source-seven/CAR-ten tuple results; `AppIcon.icns` parse smoke check; Debug/Release resolved AppIcon setting; clean configured build and compiled Info.plist/assetutil results; strict signing identity/team/runtime/effective entitlements; alternate-bundle path/identity, active Debug suppression, and empty isolated notification-table evidence before visual relaunch; Finder/Dock/About captures and checklist result; absence of shipped generated raster, owner credential access/data access, and delivery; all independent decisions; any approved visual deviation; residual local-development-only distribution limitation; and final remediation milestone status in `docs/delivery/progress.md`.
