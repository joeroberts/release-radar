#!/bin/bash
set -euo pipefail
# Fixed offline dependency preparation. This never downloads or installs anything.
RR_PROJECT_ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
RR_LIBGIT_REVISION="f7a4071c766ceea3915415e22134cbe3e581c420"
RR_LIBGIT_SHA="ce61c6a669de14f8dd3f9f17affe371e69d2e43bdd8e6a3df58c413807266323"
RR_LIBGIT_ARCHIVE="$RR_PROJECT_ROOT/ReleaseRadar/ThirdPartyNotices/libgit2-source.tar.gz"
RR_CMAKE="${CMAKE_EXECUTABLE:-cmake}"
RR_BUILD_ARCH="${CURRENT_ARCH:-${1:-arm64}}"
case "$RR_BUILD_ARCH" in arm64|x86_64) ;; *) echo "Unsupported libgit2 build architecture: $RR_BUILD_ARCH" >&2; exit 1 ;; esac
if ! command -v "$RR_CMAKE" >/dev/null 2>&1; then
    echo "CMake is unavailable. Set CMAKE_EXECUTABLE to your development CMake executable; no runtime installation is required." >&2
    exit 1
fi
RR_ACTUAL_SHA="$(/usr/bin/shasum -a 256 "$RR_LIBGIT_ARCHIVE" | /usr/bin/awk '{print $1}')"
if [ "$RR_ACTUAL_SHA" != "$RR_LIBGIT_SHA" ]; then echo "Pinned libgit2 source archive integrity failed." >&2; exit 1; fi
RR_LIBGIT_SOURCE="$RR_PROJECT_ROOT/.build/native-source/libgit2-$RR_LIBGIT_REVISION"
RR_LIBGIT_BUILD="$RR_PROJECT_ROOT/.build/libgit2/$RR_BUILD_ARCH"
if [ ! -d "$RR_LIBGIT_SOURCE" ]; then
    /bin/mkdir -p "$RR_PROJECT_ROOT/.build/native-source"
    /usr/bin/tar -xzf "$RR_LIBGIT_ARCHIVE" -C "$RR_PROJECT_ROOT/.build/native-source"
fi
"$RR_CMAKE" -S "$RR_LIBGIT_SOURCE" -B "$RR_LIBGIT_BUILD" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$RR_BUILD_ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF -DBUILD_EXAMPLES=OFF -DBUILD_FUZZERS=OFF \
    -DUSE_HTTPS=OFF -DUSE_SSH=OFF -DUSE_NTLMCLIENT=OFF -DUSE_GSSAPI=OFF \
    -DREGEX_BACKEND=regcomp -DUSE_SHA256=Builtin -DENABLE_REPRODUCIBLE_BUILDS=OFF
# Apple ar/ranlib do not accept upstream GNU -D flags. ZERO_AR_DATE is Apple’s
# supported archive timestamp control; source pinning/offline inputs remain fixed.
env ZERO_AR_DATE=1 "$RR_CMAKE" --build "$RR_LIBGIT_BUILD" --config Release --parallel 4
