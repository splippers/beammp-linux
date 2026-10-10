#!/usr/bin/env bash
#
# update-beammp.sh - rebuild the native Linux BeamMP-Launcher from the latest
# upstream release.
#
# On Linux BeamMP does not ship a prebuilt binary, so every launcher release
# has to be compiled. This script reproduces the local build using the system
# libraries (libcurl, openssl, zlib, nlohmann-json) plus the upstream
# header-only cpp-httplib, which avoids the slow vcpkg/OpenSSL-from-source
# build described in the official docs.
#
# Usage:   ./update-beammp.sh
# Re-run it any time BeamMP publishes a new launcher release.

set -euo pipefail

SRC_DIR="${BEAMMP_SRC:-$HOME/.cache/beammp-launcher-src}"
INSTALL_DIR="$HOME/beammp-launcher"
HTTPLIB_VERSION="v0.26.0"   # bump if a future launcher requires a newer cpp-httplib

echo "==> Looking up the latest BeamMP-Launcher release"
TAG="$(curl -fsSL https://api.github.com/repos/BeamMP/BeamMP-Launcher/releases/latest \
        | grep -m1 '"tag_name"' | cut -d'"' -f4)"
[ -n "$TAG" ] || { echo "Could not determine latest release tag" >&2; exit 1; }
echo "    Latest release: $TAG"

echo "==> Fetching source"
if [ -d "$SRC_DIR/.git" ]; then
    git -C "$SRC_DIR" fetch --tags --depth 1 origin "$TAG" 2>/dev/null \
        || git -C "$SRC_DIR" fetch --tags
    git -C "$SRC_DIR" checkout --force "$TAG"
else
    rm -rf "$SRC_DIR"
    git clone --branch "$TAG" --depth 1 \
        https://github.com/BeamMP/BeamMP-Launcher.git "$SRC_DIR"
fi

echo "==> Providing header-only cpp-httplib ($HTTPLIB_VERSION)"
mkdir -p "$SRC_DIR/third_party/httplib" "$SRC_DIR/httplib-cmake"
curl -fsSL -o "$SRC_DIR/third_party/httplib/httplib.h" \
    "https://raw.githubusercontent.com/yhirose/cpp-httplib/$HTTPLIB_VERSION/httplib.h"

cat > "$SRC_DIR/httplib-cmake/httplibConfig.cmake" <<'EOF'
if(NOT TARGET httplib::httplib)
  add_library(httplib::httplib INTERFACE IMPORTED)
  set_target_properties(httplib::httplib PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../third_party/httplib"
    INTERFACE_COMPILE_FEATURES "cxx_std_11")
endif()
set(httplib_FOUND TRUE)
EOF

# Debian's libcpp-httplib-dev has no CMake config and ships a decl-only header
# built with extra feature macros; use our own header and link the target so
# its include directory is picked up on the UNIX link line.
if ! grep -q "httplib::httplib" "$SRC_DIR/CMakeLists.txt"; then
    sed -i \
      's|ZLIB::ZLIB OpenSSL::SSL OpenSSL::Crypto CURL::libcurl|ZLIB::ZLIB OpenSSL::SSL OpenSSL::Crypto httplib::httplib CURL::libcurl|' \
      "$SRC_DIR/CMakeLists.txt"
fi

echo "==> Configuring and building (Debug, per upstream guidance)"
rm -rf "$SRC_DIR/bin"
cmake -S "$SRC_DIR" -B "$SRC_DIR/bin" -Dhttplib_DIR="$SRC_DIR/httplib-cmake"
cmake --build "$SRC_DIR/bin" --parallel

echo "==> Installing to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/bin/BeamMP-Launcher" "$INSTALL_DIR/"
echo "==> Done: $INSTALL_DIR/BeamMP-Launcher updated to $TAG"
