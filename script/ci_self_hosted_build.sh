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
command -v xcodebuild >/dev/null || { echo 'Xcode is unavailable on the runner.' >&2; exit 1; }
cmake_binary="${CMAKE_EXECUTABLE:-}"
if [[ -z "$cmake_binary" ]]; then
    cmake_binary="$(command -v cmake || true)"
fi
if [[ -n "$cmake_binary" && "$cmake_binary" != /* ]]; then
    cmake_binary="$(command -v "$cmake_binary" || true)"
fi
if [[ -z "$cmake_binary" ]]; then
    for candidate in /opt/homebrew/bin/cmake /usr/local/bin/cmake /Applications/CMake.app/Contents/bin/cmake; do
        if [[ -x "$candidate" ]]; then cmake_binary="$candidate"; break; fi
    done
fi
[[ -n "$cmake_binary" && -x "$cmake_binary" ]] || { echo 'CMake is unavailable on the runner (PATH and standard installation paths checked).' >&2; exit 1; }
export CMAKE_EXECUTABLE="$cmake_binary"

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

echo "Source revision: $GITHUB_SHA"
echo "Runner architecture: $(uname -m)"
echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
xcodebuild -version
echo "CMake: $("$CMAKE_EXECUTABLE" --version | head -n 1)"

# The Air's existing Git credential configuration must read the private RDS
# repository. No credential is copied into the checkout or Actions artifact.
run_private rds-access env GIT_TERMINAL_PROMPT=0 git ls-remote \
    https://github.com/joeroberts/RekonDesignSystem.git HEAD
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

echo "Unsigned Release app built: $version ($build)."
echo "Private archive and checksum retained in the Air's runner workspace for run $GITHUB_RUN_ID attempt $GITHUB_RUN_ATTEMPT."
echo 'No app installation, GUI test, signing, DMG packaging, tag, release, or public artifact upload occurred.'
