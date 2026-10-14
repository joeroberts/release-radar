#!/usr/bin/env bash
# A private unsigned build on the owner's self-hosted runner. Never upload the
# compiled app or private Xcode diagnostics to the public repository.
set -euo pipefail
umask 077

[[ "${GITHUB_REPOSITORY:-}" == joeroberts/release-radar ]] || { echo 'Unexpected repository.' >&2; exit 1; }
[[ "${GITHUB_REF:-}" == refs/heads/main ]] || { echo 'Native builds require main.' >&2; exit 1; }
[[ "${GITHUB_EVENT_NAME:-}" == push || "${GITHUB_EVENT_NAME:-}" == workflow_dispatch ]] || { echo 'Unsupported event.' >&2; exit 1; }
[[ "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || { echo 'Missing source revision.' >&2; exit 1; }
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]] || { echo 'Missing run identity.' >&2; exit 1; }
: "${RUNNER_WORKSPACE:?Runner workspace is required}"
: "${RUNNER_TEMP:?Runner temporary directory is required}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$GITHUB_SHA" ]] || { echo 'Checkout does not match the event revision.' >&2; exit 1; }
[[ "$(uname -m)" == arm64 ]] || { echo 'The runner must be Apple silicon.' >&2; exit 1; }

private_root="$RUNNER_WORKSPACE/release-radar-internal-builds"
[[ ! -L "$private_root" ]] || { echo 'Private build root cannot be a symlink.' >&2; exit 1; }
mkdir -p "$private_root"
chmod 700 "$private_root"
run_dir="$private_root/$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
mkdir "$run_dir"
derived_data="$RUNNER_TEMP/rr-derived-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
package_sources="$RUNNER_TEMP/rr-packages-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
[[ ! -e "$derived_data" && ! -e "$package_sources" ]] || { echo 'Temporary build destination already exists.' >&2; exit 1; }

run_private() {
    local stage="$1"
    local status=0
    shift
    "$@" > "$run_dir/$stage.log" 2>&1 || status=$?
    if [[ "$status" -ne 0 ]]; then
        echo "$stage failed (exit $status); inspect the private $stage.log on the Air." >&2
        exit "$status"
    fi
    echo "$stage passed."
}

prepare_cmake() {
    local candidate archive tool_dir actual_sha
    cmake_binary="${CMAKE_EXECUTABLE:-}"
    if [[ -z "$cmake_binary" ]]; then cmake_binary="$(command -v cmake || true)"; fi
    if [[ -n "$cmake_binary" && "$cmake_binary" != /* ]]; then
        cmake_binary="$(command -v "$cmake_binary" || true)"
    fi
    if [[ -z "$cmake_binary" ]]; then
        for candidate in /opt/homebrew/bin/cmake /usr/local/bin/cmake /Applications/CMake.app/Contents/bin/cmake; do
            if [[ -x "$candidate" ]]; then cmake_binary="$candidate"; break; fi
        done
    fi
    if [[ -n "$cmake_binary" && -x "$cmake_binary" ]]; then
        export CMAKE_EXECUTABLE="$cmake_binary"
        return 0
    fi

    # Kitware's official universal macOS asset, pinned by its release SHA-256.
    tool_dir="$RUNNER_TEMP/rr-cmake-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
    mkdir "$tool_dir" || return 1
    archive="$tool_dir/cmake-3.31.10-macos-universal.tar.gz"
    if ! curl -fsSL \
        https://github.com/Kitware/CMake/releases/download/v3.31.10/cmake-3.31.10-macos-universal.tar.gz \
        -o "$archive" > "$run_dir/cmake-download.log" 2>&1; then
        echo 'Pinned CMake download failed; inspect the private cmake-download.log on the Air.' >&2
        return 1
    fi
    actual_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
    if [[ "$actual_sha" != be9f3faeeaf7921cc2d77cea711dd5e6f72c63af2810cacd9205b3ce8d1593c9 ]]; then
        echo 'Pinned CMake archive integrity check failed.' >&2
        return 1
    fi
    if ! tar -xzf "$archive" -C "$tool_dir" > "$run_dir/cmake-extract.log" 2>&1; then
        echo 'Pinned CMake extraction failed; inspect the private cmake-extract.log on the Air.' >&2
        return 1
    fi
    cmake_binary="$(find "$tool_dir" -type f -path '*/bin/cmake' -print -quit)"
    [[ -n "$cmake_binary" && -x "$cmake_binary" ]] || { echo 'Pinned CMake executable is missing from the verified archive.' >&2; return 1; }
    export CMAKE_EXECUTABLE="$cmake_binary"
}

echo "Source revision: $GITHUB_SHA"
echo "Runner architecture: $(uname -m)"
echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
preflight_failed=false
if command -v xcodebuild >/dev/null && xcodebuild -version > "$run_dir/xcode-version.log" 2>&1; then
    cat "$run_dir/xcode-version.log"
else
    echo 'Xcode is unavailable or its license is not accepted; inspect the private xcode-version.log on the Air.' >&2
    preflight_failed=true
fi

# The Air's existing Git credential configuration must read the private RDS
# repository. No credential is copied into the checkout or Actions artifact.
if env GIT_TERMINAL_PROMPT=0 git ls-remote \
    https://github.com/joeroberts/RekonDesignSystem.git HEAD > "$run_dir/rds-access.log" 2>&1; then
    echo 'rds-access passed.'
else
    echo 'rds-access failed; inspect the private rds-access.log on the Air.' >&2
    preflight_failed=true
fi

if prepare_cmake && "$CMAKE_EXECUTABLE" --version > "$run_dir/cmake-version.log" 2>&1; then
    echo "CMake: $(head -n 1 "$run_dir/cmake-version.log")"
else
    echo 'CMake is unavailable; inspect private CMake diagnostics on the Air.' >&2
    preflight_failed=true
fi
[[ "$preflight_failed" == false ]] || exit 1

run_private libgit2 bash script/build_libgit2.sh arm64
run_private packages env GIT_TERMINAL_PROMPT=0 xcodebuild \
    -resolvePackageDependencies -project ReleaseRadar.xcodeproj \
    -scheme ReleaseRadar -clonedSourcePackagesDirPath "$package_sources"
run_private build env GIT_TERMINAL_PROMPT=0 xcodebuild \
    -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
    -configuration Release -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$package_sources" \
    ARCHS=arm64 CODE_SIGNING_ALLOWED=NO CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build

bundle="$derived_data/Build/Products/Release/ReleaseRadar.app"
[[ -d "$bundle" && -x "$bundle/Contents/MacOS/ReleaseRadar" ]] || { echo 'Release app output is missing.' >&2; exit 1; }
[[ ! -e "$bundle/Contents/_CodeSignature/CodeResources" ]] || { echo 'Unexpected signed app output.' >&2; exit 1; }
bundle_id="$(plutil -extract CFBundleIdentifier raw "$bundle/Contents/Info.plist")"
version="$(plutil -extract CFBundleShortVersionString raw "$bundle/Contents/Info.plist")"
build="$(plutil -extract CFBundleVersion raw "$bundle/Contents/Info.plist")"
[[ "$bundle_id" == com.rekonlabs.ReleaseRadar && -n "$version" && -n "$build" ]] || { echo 'Bundle identity is invalid.' >&2; exit 1; }

archive="ReleaseRadar-ci-$GITHUB_SHA.zip"
run_private archive ditto -c -k --sequesterRsrc --keepParent "$bundle" "$run_dir/$archive"
digest="$(shasum -a 256 "$run_dir/$archive" | awk '{print $1}')"
printf '%s  %s\n' "$digest" "$archive" > "$run_dir/$archive.sha256"
export RR_CI_VERSION="$version" RR_CI_BUILD="$build" RR_CI_ARCHIVE="$archive" RR_CI_DIGEST="$digest"
export RR_CI_XCODE="$(xcodebuild -version | tr '\n' ' ')"
export RR_CI_MACOS="$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
export RR_CI_LIBGIT_DIGEST="$(shasum -a 256 ReleaseRadar/ThirdPartyNotices/libgit2-source.tar.gz | awk '{print $1}')"
python3 - "$run_dir/manifest.json" <<'PY'
import json
import os
import sys
from pathlib import Path

resolved = json.loads(Path("ReleaseRadar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
rds = next(pin for pin in resolved["pins"] if pin["identity"] == "rekondesignsystem")
manifest = {
    "source_revision": os.environ["GITHUB_SHA"],
    "run_id": os.environ["GITHUB_RUN_ID"],
    "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
    "bundle_identifier": "com.rekonlabs.ReleaseRadar",
    "version": os.environ["RR_CI_VERSION"],
    "build": os.environ["RR_CI_BUILD"],
    "architecture": "arm64",
    "macos": os.environ["RR_CI_MACOS"],
    "xcode": os.environ["RR_CI_XCODE"].strip(),
    "rds_revision": rds["state"]["revision"],
    "libgit2_source_sha256": os.environ["RR_CI_LIBGIT_DIGEST"],
    "archive": os.environ["RR_CI_ARCHIVE"],
    "archive_sha256": os.environ["RR_CI_DIGEST"],
    "signing": "unsigned; local signing and release packaging remain separate",
    "checks": {"rds_access": "passed", "libgit2": "passed", "package_resolution": "passed", "release_build": "passed"},
}
Path(sys.argv[1]).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PY

run_private smb-delivery python3 script/deliver_ci_artifact.py "$run_dir" "$archive"

echo "Unsigned Release app built: $version ($build)."
echo "Private archive, checksum, and manifest retained on the Air and verified on the owner's SMB share for run $GITHUB_RUN_ID attempt $GITHUB_RUN_ATTEMPT."
echo 'No app installation, GUI test, signing, DMG packaging, tag, release, or public artifact upload occurred.'
