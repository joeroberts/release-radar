#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNT_NAME="$(id -un)"
ACCOUNT_HOME="$(dscl . -read "/Users/$ACCOUNT_NAME" NFSHomeDirectory | awk '{ print $2 }')"
FIXTURE_PARENT="$ACCOUNT_HOME/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp"
mkdir -p "$FIXTURE_PARENT"
FIXTURE_ROOT="$(mktemp -d "$FIXTURE_PARENT/release-radar-isolated-helper.XXXXXX")"
CURRENT_RESOURCES="$FIXTURE_ROOT/Current.app/Contents/Resources"
LEGACY_RESOURCES="$FIXTURE_ROOT/Legacy.app/Contents/Resources"
ACTIVE_RESOURCES="$FIXTURE_ROOT/Active.app/Contents/Resources"
CURRENT_HELPER="$CURRENT_RESOURCES/ReleaseRadarPluginLifecycleHelper"
LEGACY_HELPER="$LEGACY_RESOURCES/ReleaseRadarPluginLifecycleHelper"
ACTIVE_HELPER="$ACTIVE_RESOURCES/ReleaseRadarPluginLifecycleHelper"
SERVICE_LABEL="com.rekonlabs.ReleaseRadar.IsolatedLifecycleHelper.test"
MACH_SERVICE="2UA854NLX4.com.rekonlabs.ReleaseRadar.isolated-restart-test"
TEST_HOME="$ACCOUNT_HOME/.codex/release-radar-tests/$(basename "$FIXTURE_ROOT")"
SERVICE_PLIST="$FIXTURE_ROOT/isolated-helper.plist"
SWIFT_COMPILER="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
MACOS_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
TEST_ARCH="$(uname -m)"
TEST_TARGET="$TEST_ARCH-apple-macos14.0"
DERIVED_DATA="${1:-$FIXTURE_ROOT/DerivedData}"

mkdir -p "$CURRENT_RESOURCES" "$LEGACY_RESOURCES" "$ACTIVE_RESOURCES"
mkdir -p "$TEST_HOME/.codex"
ditto "$REPOSITORY_ROOT/ReleaseRadar/CodexPluginMarketplace" "$CURRENT_RESOURCES/CodexPluginMarketplace"
ditto "$REPOSITORY_ROOT/ReleaseRadar/CodexPluginMarketplace" "$LEGACY_RESOURCES/CodexPluginMarketplace"
ditto "$REPOSITORY_ROOT/ReleaseRadar/CodexPluginMarketplace" "$ACTIVE_RESOURCES/CodexPluginMarketplace"
rm "$LEGACY_RESOURCES/CodexPluginMarketplace/plugins/release-radar/skills/shared-execution/SKILL.md"

"$SWIFT_COMPILER" \
    "$REPOSITORY_ROOT/ReleaseRadarPluginLifecycleHelper/main.swift" \
    -o "$CURRENT_HELPER" \
    -sdk "$MACOS_SDK" \
    -target "$TEST_TARGET" \
    -D RELEASE_RADAR_ISOLATED_TEST
"$SWIFT_COMPILER" \
    "$REPOSITORY_ROOT/ReleaseRadarPluginLifecycleHelper/main.swift" \
    -o "$LEGACY_HELPER" \
    -sdk "$MACOS_SDK" \
    -target "$TEST_TARGET" \
    -D RELEASE_RADAR_ISOLATED_TEST \
    -D RELEASE_RADAR_LEGACY_PLUGIN_INVENTORY

for helper in "$CURRENT_HELPER" "$LEGACY_HELPER"; do
    codesign --force --sign - \
        --identifier com.rekonlabs.ReleaseRadarPluginLifecycleHelper \
        --options runtime \
        --timestamp=none \
        "$helper"
    codesign --verify --strict \
        --test-requirement '=identifier "com.rekonlabs.ReleaseRadarPluginLifecycleHelper"' \
        "$helper"
done

printf 'ISOLATED_RESTART_HELPER_FIXTURE=%s\n' "$FIXTURE_ROOT"
ln -sfn "$FIXTURE_ROOT" "$FIXTURE_PARENT/release-radar-isolated-helper-current"
ln -sfn "$CURRENT_HELPER" "$ACTIVE_HELPER"

plutil -create xml1 "$SERVICE_PLIST"
/usr/libexec/PlistBuddy \
    -c "Add :Label string $SERVICE_LABEL" \
    -c "Add :ProgramArguments array" \
    -c "Add :ProgramArguments:0 string $ACTIVE_HELPER" \
    -c "Add :MachServices dict" \
    -c "Add :MachServices:$MACH_SERVICE bool true" \
    -c "Add :EnvironmentVariables dict" \
    -c "Add :EnvironmentVariables:RELEASE_RADAR_TEST_HOME string $TEST_HOME" \
    -c "Add :EnvironmentVariables:RELEASE_RADAR_TEST_MACH_SERVICE string $MACH_SERVICE" \
    -c "Add :EnvironmentVariables:RELEASE_RADAR_TEST_SHUTDOWN_FILE string $FIXTURE_ROOT/shutdown" \
    "$SERVICE_PLIST"

stop_isolated_service() {
    launchctl bootout "gui/$(id -u)/$SERVICE_LABEL" >/dev/null 2>&1 || true
}
trap stop_isolated_service EXIT
stop_isolated_service
launchctl bootstrap "gui/$(id -u)" "$SERVICE_PLIST"

xcodebuild test \
    -project "$REPOSITORY_ROOT/ReleaseRadar.xcodeproj" \
    -scheme ReleaseRadar \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:ReleaseRadarTests/CodexPluginLifecycleTransportTests/testSettingsRestartHandsOffAnIsolatedLegacyHelperProcessToTheCurrentHelper
