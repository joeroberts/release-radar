#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-stage-release-no-launch}"
APP_NAME="ReleaseRadar"
BUNDLE_ID="com.rekonlabs.ReleaseRadar"
TEAM_ID="2UA854NLX4"
APP_GROUP="2UA854NLX4.com.rekonlabs.ReleaseRadar"
SIGNING_AUTHORITY="Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"
BRIDGE_SERVICE_LABEL="com.rekonlabs.ReleaseRadar.BridgeAgent"
PLUGIN_LIFECYCLE_SERVICE_LABEL="com.rekonlabs.ReleaseRadar.PluginLifecycleHelper"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData"
BUILD_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
BUILD_BINARY="$BUILD_BUNDLE/Contents/MacOS/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"
STAGED_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALLED_BUNDLE="/Applications/$APP_NAME.app"

report_error() {
    printf 'error: %s\n' "$*" >&2
}

wait_for_process_exit() {
    local pid="$1"
    local description="$2"
    local attempt

    for ((attempt = 0; attempt < 50; attempt++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
    done
    report_error "$description process $pid did not stop"
    return 1
}

stop_exact_executable() {
    local executable_path="$1"
    local pid
    local pids

    pids="$(pgrep -f -x "$executable_path" 2>/dev/null || true)"
    for pid in $pids; do
        if ! kill -TERM "$pid" 2>/dev/null && kill -0 "$pid" 2>/dev/null; then
            report_error "could not stop Release Radar executable $executable_path (pid $pid)"
            return 1
        fi
    done
    for pid in $pids; do
        if ! wait_for_process_exit "$pid" "$executable_path"; then return 1; fi
    done
}

stop_launchd_service() {
    local service_label="$1"
    local service_target="gui/$(id -u)/$service_label"
    local service_state
    local pid

    if ! service_state="$(launchctl print "$service_target" 2>/dev/null)"; then
        return 0
    fi
    pid="$(awk '/^[[:space:]]*pid = / {print $3; exit}' <<<"$service_state")"
    if [[ -z "$pid" ]]; then
        return 0
    fi
    if ! launchctl kill SIGTERM "$service_target" 2>/dev/null && kill -0 "$pid" 2>/dev/null; then
        report_error "could not stop Release Radar service $service_label (pid $pid)"
        return 1
    fi
    wait_for_process_exit "$pid" "$service_label"
}

stop_running_release_radar_processes() {
    stop_exact_executable "$INSTALLED_BUNDLE/Contents/MacOS/$APP_NAME"
    stop_exact_executable "$BUILD_BUNDLE/Contents/MacOS/$APP_NAME"
    stop_launchd_service "$BRIDGE_SERVICE_LABEL"
    stop_launchd_service "$PLUGIN_LIFECYCLE_SERVICE_LABEL"
}

require_value() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    if [[ "$actual" != "$expected" ]]; then
        report_error "$description was '$actual', expected '$expected'"
        return 1
    fi
}

signing_metadata() {
    codesign -dvvv "$1" 2>&1
}

verify_signed_code() {
    local code_path="$1"
    local metadata

    if [[ ! -e "$code_path" ]]; then
        report_error "missing signed code at $code_path"
        return 1
    fi
    if ! codesign --verify --strict --verbose=2 "$code_path"; then
        report_error "strict signature verification failed for $code_path"
        return 1
    fi
    if ! metadata="$(signing_metadata "$code_path")"; then
        report_error "could not inspect signing metadata for $code_path"
        return 1
    fi
    if ! grep -Fxq "Authority=$SIGNING_AUTHORITY" <<<"$metadata"; then
        report_error "configured signing authority mismatch for $code_path"
        return 1
    fi
    if ! grep -Fxq "TeamIdentifier=$TEAM_ID" <<<"$metadata"; then
        report_error "team identifier mismatch for $code_path"
        return 1
    fi
    return 0
}

verify_hardened_runtime() {
    local code_path="$1"
    local metadata

    if ! metadata="$(signing_metadata "$code_path")"; then
        report_error "could not inspect signing metadata for $code_path"
        return 1
    fi
    if ! grep -Eq 'flags=.*runtime' <<<"$metadata"; then
        report_error "Hardened Runtime missing for $code_path"
        return 1
    fi
    return 0
}

entitlements_for() {
    codesign -dvvv --entitlements :- "$1" 2>/dev/null
}

canonicalize_entitlements() {
    plutil -convert xml1 -o - -
}

expected_main_entitlements() {
    printf '%s\n' \
        '<?xml version="1.0" encoding="UTF-8"?>' \
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
        '<plist version="1.0">' \
        '<dict>' \
        '<key>com.apple.security.app-sandbox</key>' \
        '<true/>' \
        '<key>com.apple.security.application-groups</key>' \
        '<array>' \
        "<string>$APP_GROUP</string>" \
        '</array>' \
        '<key>com.apple.security.files.user-selected.read-only</key>' \
        '<true/>' \
        '<key>com.apple.security.network.client</key>' \
        '<true/>' \
        '</dict>' \
        '</plist>'
}

expected_bridge_entitlements() {
    printf '%s\n' \
        '<?xml version="1.0" encoding="UTF-8"?>' \
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
        '<plist version="1.0">' \
        '<dict>' \
        '<key>com.apple.security.app-sandbox</key>' \
        '<true/>' \
        '<key>com.apple.security.application-groups</key>' \
        '<array>' \
        "<string>$APP_GROUP</string>" \
        '</array>' \
        '</dict>' \
        '</plist>'
}

assert_exact_entitlements() {
    local code_path="$1"
    local entitlement_description="$2"
    local expected_entitlements="$3"
    local entitlements
    local actual_canonical
    local expected_canonical

    if ! entitlements="$(entitlements_for "$code_path")" || [[ -z "$entitlements" ]]; then
        report_error "missing entitlements for $code_path"
        return 1
    fi
    if ! actual_canonical="$(printf '%s' "$entitlements" | canonicalize_entitlements)"; then
        report_error "could not parse $entitlement_description entitlements for $code_path"
        return 1
    fi
    if ! expected_canonical="$(printf '%s' "$expected_entitlements" | canonicalize_entitlements)"; then
        report_error "could not construct expected $entitlement_description entitlements"
        return 1
    fi
    if [[ "$actual_canonical" != "$expected_canonical" ]]; then
        report_error "$entitlement_description entitlements differ from the exact approved structure for $code_path"
        return 1
    fi
    return 0
}

assert_main_entitlements() {
    local code_path="$1"
    if ! assert_exact_entitlements "$code_path" "main app" "$(expected_main_entitlements)"; then
        return 1
    fi
    return 0
}

assert_bridge_entitlements() {
    local code_path="$1"
    if ! assert_exact_entitlements "$code_path" "Bridge Agent" "$(expected_bridge_entitlements)"; then
        return 1
    fi
    return 0
}

bundle_identifier() {
    plutil -extract CFBundleIdentifier raw "$1/Contents/Info.plist"
}

bundle_version() {
    plutil -extract CFBundleShortVersionString raw "$1/Contents/Info.plist"
}

bundle_build() {
    plutil -extract CFBundleVersion raw "$1/Contents/Info.plist"
}

bundle_cdhash() {
    signing_metadata "$1" | /usr/bin/sed -nE 's/^CDHash=//p' | head -n 1
}

bundle_executable_sha256() {
    shasum -a 256 "$1/Contents/MacOS/$APP_NAME" | /usr/bin/awk '{ print $1 }'
}

bundle_resource_manifest_sha256() {
    shasum -a 256 "$1/Contents/_CodeSignature/CodeResources" | /usr/bin/awk '{ print $1 }'
}

verify_bundle() {
    local bundle="$1"
    local bridge_agent="$bundle/Contents/Resources/ReleaseRadarBridgeAgent"
    local executable
    local framework

    if [[ ! -d "$bundle" ]]; then
        report_error "missing bundle at $bundle"
        return 1
    fi
    if [[ ! -f "$bundle/Contents/Info.plist" ]]; then
        report_error "missing Info.plist in $bundle"
        return 1
    fi
    if [[ ! -x "$bundle/Contents/MacOS/$APP_NAME" ]]; then
        report_error "missing main executable in $bundle"
        return 1
    fi
    if [[ ! -f "$bundle/Contents/_CodeSignature/CodeResources" ]]; then
        report_error "missing signed resource manifest in $bundle"
        return 1
    fi

    if ! codesign --verify --deep --strict --verbose=2 "$bundle"; then
        report_error "strict bundle verification failed for $bundle"
        return 1
    fi
    if ! signing_metadata "$bundle" >/dev/null; then
        report_error "could not inspect signing metadata for $bundle"
        return 1
    fi
    if ! require_value "$(bundle_identifier "$bundle")" "$BUNDLE_ID" "bundle identifier"; then return 1; fi
    if [[ -z "$(bundle_version "$bundle")" ]]; then report_error "missing bundle version"; return 1; fi
    if [[ -z "$(bundle_build "$bundle")" ]]; then report_error "missing bundle build"; return 1; fi
    if [[ -z "$(bundle_cdhash "$bundle")" ]]; then report_error "missing CodeDirectory hash"; return 1; fi

    if ! verify_signed_code "$bundle"; then return 1; fi
    if ! verify_hardened_runtime "$bundle"; then return 1; fi
    if ! assert_main_entitlements "$bundle"; then return 1; fi

    if ! verify_signed_code "$bridge_agent"; then return 1; fi
    if ! verify_hardened_runtime "$bridge_agent"; then return 1; fi
    if ! assert_bridge_entitlements "$bridge_agent"; then return 1; fi

    while IFS= read -r -d '' executable; do
        if ! verify_signed_code "$executable"; then return 1; fi
    done < <(/usr/bin/find "$bundle/Contents" -type f -perm +111 -print0)
    if [[ -d "$bundle/Contents/Frameworks" ]]; then
        while IFS= read -r -d '' framework; do
            if ! verify_signed_code "$framework"; then return 1; fi
        done < <(/usr/bin/find "$bundle/Contents/Frameworks" -type d -name '*.framework' -print0)
    fi
    return 0
}

bundle_identity() {
    local bundle="$1"

    local cdhash
    local identifier
    local version
    local build
    local executable_hash
    local resource_hash

    if ! cdhash="$(bundle_cdhash "$bundle")" || [[ -z "$cdhash" ]]; then return 1; fi
    if ! identifier="$(bundle_identifier "$bundle")" || [[ -z "$identifier" ]]; then return 1; fi
    if ! version="$(bundle_version "$bundle")" || [[ -z "$version" ]]; then return 1; fi
    if ! build="$(bundle_build "$bundle")" || [[ -z "$build" ]]; then return 1; fi
    if ! executable_hash="$(bundle_executable_sha256 "$bundle")" || [[ -z "$executable_hash" ]]; then return 1; fi
    if ! resource_hash="$(bundle_resource_manifest_sha256 "$bundle")" || [[ -z "$resource_hash" ]]; then return 1; fi
    printf '%s\n' "$cdhash" "$identifier" "$version" "$build" "$executable_hash" "$resource_hash"
}

require_matching_bundle_identity() {
    local source_bundle="$1"
    local copied_bundle="$2"

    local source_identity
    local copied_identity

    if ! source_identity="$(bundle_identity "$source_bundle")"; then
        report_error "could not determine source bundle identity for $source_bundle"
        return 1
    fi
    if ! copied_identity="$(bundle_identity "$copied_bundle")"; then
        report_error "could not determine copied bundle identity for $copied_bundle"
        return 1
    fi
    if [[ "$source_identity" != "$copied_identity" ]]; then
        report_error "bundle identity mismatch between $source_bundle and $copied_bundle"
        return 1
    fi
}

recover_failed_promotion() {
    local final_bundle="$1"
    local backup_bundle="$2"
    local had_backup="$3"
    local failed_bundle="$4"

    if [[ -e "$final_bundle" ]]; then
        if ! mv "$final_bundle" "$failed_bundle"; then
            report_error "failed final remains at $final_bundle; prior bundle remains at $backup_bundle"
            return 1
        fi
    fi
    if [[ "$had_backup" == true ]]; then
        if ! mv "$backup_bundle" "$final_bundle"; then
            report_error "rollback restoration failed; failed bundle is at $failed_bundle and prior bundle remains at $backup_bundle"
            return 1
        fi
    fi
    return 0
}

promote_verified_bundle() {
    local candidate="$1"
    local final_bundle="$2"
    local expected_identity="${3:-}"
    local final_parent
    local backup_bundle
    local failed_bundle
    local final_identity
    local had_backup=false

    final_parent="$(dirname "$final_bundle")"
    backup_bundle="$final_parent/.${APP_NAME}.backup.$$.$RANDOM"
    failed_bundle="$final_parent/.${APP_NAME}.failed.$$.$RANDOM"
    if [[ ! -d "$candidate" ]]; then
        report_error "candidate bundle missing at $candidate"
        return 1
    fi
    if ! verify_bundle "$candidate"; then
        report_error "candidate bundle failed verification at $candidate"
        return 1
    fi
    if [[ -z "$expected_identity" ]]; then
        if ! expected_identity="$(bundle_identity "$candidate")"; then
            report_error "could not determine candidate bundle identity for $candidate"
            return 1
        fi
    fi

    if [[ -e "$final_bundle" ]]; then
        if ! verify_bundle "$final_bundle"; then
            report_error "prior final bundle failed verification at $final_bundle; refusing replacement"
            return 1
        fi
        if ! mv "$final_bundle" "$backup_bundle"; then
            report_error "could not preserve prior bundle at $final_bundle"
            return 1
        fi
        had_backup=true
    fi

    if ! mv "$candidate" "$final_bundle"; then
        report_error "promotion failed; candidate remains at $candidate"
        if [[ "$had_backup" == true ]] && ! mv "$backup_bundle" "$final_bundle"; then
            report_error "rollback failed; prior bundle remains at $backup_bundle"
        fi
        return 1
    fi

    if ! verify_bundle "$final_bundle"; then
        report_error "promoted candidate failed verification at $final_bundle"
        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
        return 1
    fi
    if ! final_identity="$(bundle_identity "$final_bundle")"; then
        report_error "could not determine promoted bundle identity at $final_bundle"
        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
        return 1
    fi
    if [[ "$expected_identity" != "$final_identity" ]]; then
        report_error "bundle identity mismatch after promotion at $final_bundle"
        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
        return 1
    fi
    if [[ "$had_backup" == true ]] && ! /bin/rm -rf "$backup_bundle"; then
        report_error "final bundle verified but prior backup cleanup failed at $backup_bundle"
        return 1
    fi
    return 0
}

build_release() {
    if ! xcodebuild \
        -project "$ROOT_DIR/ReleaseRadar.xcodeproj" \
        -scheme ReleaseRadar \
        -configuration Release \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
        -derivedDataPath "$DERIVED_DATA" \
        build; then
        return 1
    fi
    verify_bundle "$BUILD_BUNDLE"
}

stage_release_no_launch() {
    local temporary_directory
    local candidate_bundle

    local source_identity

    if ! build_release; then return 1; fi
    if ! mkdir -p "$DIST_DIR"; then report_error "could not create $DIST_DIR"; return 1; fi
    if ! temporary_directory="$(mktemp -d "$DIST_DIR/.${APP_NAME}.stage.XXXXXX")"; then report_error "could not create stage temporary directory"; return 1; fi
    candidate_bundle="$temporary_directory/$APP_NAME.app"
    if ! ditto "$BUILD_BUNDLE" "$candidate_bundle"; then report_error "could not copy Release bundle into stage candidate"; return 1; fi
    if ! verify_bundle "$candidate_bundle"; then return 1; fi
    if ! source_identity="$(bundle_identity "$BUILD_BUNDLE")"; then report_error "could not determine build bundle identity"; return 1; fi
    if ! require_matching_bundle_identity "$BUILD_BUNDLE" "$candidate_bundle"; then return 1; fi
    if ! promote_verified_bundle "$candidate_bundle" "$STAGED_BUNDLE" "$source_identity"; then return 1; fi
    if ! rmdir "$temporary_directory"; then report_error "could not remove empty stage temporary directory $temporary_directory"; return 1; fi
    echo "staged verified Release bundle at $STAGED_BUNDLE"
}

install_staged_release_no_launch() {
    local temporary_directory
    local candidate_bundle

    local source_identity

    stop_running_release_radar_processes
    if ! verify_bundle "$STAGED_BUNDLE"; then return 1; fi
    if ! temporary_directory="$(mktemp -d "/Applications/.${APP_NAME}.install.XXXXXX")"; then report_error "could not create install temporary directory"; return 1; fi
    candidate_bundle="$temporary_directory/$APP_NAME.app"
    if ! ditto "$STAGED_BUNDLE" "$candidate_bundle"; then report_error "could not copy staged bundle into install candidate"; return 1; fi
    if ! verify_bundle "$candidate_bundle"; then return 1; fi
    if ! source_identity="$(bundle_identity "$STAGED_BUNDLE")"; then report_error "could not determine staged bundle identity"; return 1; fi
    if ! require_matching_bundle_identity "$STAGED_BUNDLE" "$candidate_bundle"; then return 1; fi
    if ! promote_verified_bundle "$candidate_bundle" "$INSTALLED_BUNDLE" "$source_identity"; then return 1; fi
    if ! rmdir "$temporary_directory"; then report_error "could not remove empty install temporary directory $temporary_directory"; return 1; fi
    echo "installed verified staged Release bundle at $INSTALLED_BUNDLE"
}

stop_running_app_for_explicit_launch() {
    stop_running_release_radar_processes
}

open_app_for_explicit_launch() {
    stop_running_app_for_explicit_launch
    /usr/bin/open -n "$BUILD_BUNDLE"
}

case "$MODE" in
    stage-release-no-launch|--stage-release-no-launch)
        stage_release_no_launch
        ;;
    install-staged-release-no-launch|--install-staged-release-no-launch)
        install_staged_release_no_launch
        ;;
    run)
        build_release
        open_app_for_explicit_launch
        ;;
    --debug|debug)
        build_release
        stop_running_app_for_explicit_launch
        lldb -- "$BUILD_BINARY"
        ;;
    --logs|logs)
        build_release
        open_app_for_explicit_launch
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        build_release
        open_app_for_explicit_launch
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        build_release
        open_app_for_explicit_launch
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        ;;
    *)
        echo "usage: $0 [stage-release-no-launch|--stage-release-no-launch|install-staged-release-no-launch|--install-staged-release-no-launch|run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
