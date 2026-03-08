#!/bin/bash
# ============================================================
# SoH 9.x Switch Build - Dependency Setup Script
# Run this ONCE before building for Nintendo Switch.
# Tested on macOS (Apple Silicon) with devkitPro installed.
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[!]${NC} $1"; exit 1; }

# ============================================================
# 1. Check devkitPro
# ============================================================
export DEVKITPRO=${DEVKITPRO:-/opt/devkitpro}
export PATH="${DEVKITPRO}/tools/bin:${DEVKITPRO}/devkitA64/bin:${PATH}"

if [ ! -d "$DEVKITPRO" ]; then
    err "devkitPro not found at $DEVKITPRO. Install from https://devkitpro.org/"
fi
log "devkitPro found at $DEVKITPRO"

SWITCH_PREFIX="$DEVKITPRO/portlibs/switch"
TOOLCHAIN="$DEVKITPRO/cmake/Switch.cmake"
AARCH64_CC="$DEVKITPRO/devkitA64/bin/aarch64-none-elf-gcc"

if [ ! -f "$TOOLCHAIN" ]; then
    err "Switch.cmake not found. Install switch-dev: dkp-pacman -S switch-dev"
fi

# ============================================================
# 2. Install devkitPro packages
# ============================================================
log "Installing devkitPro packages..."
sudo dkp-pacman -S --needed --noconfirm \
    switch-dev \
    switch-sdl2 \
    switch-zlib \
    switch-bzip2 \
    switch-tinyxml2 \
    switch-libpng \
    switch-mesa \
    switch-glm \
    switch-libdrm_nouveau

log "devkitPro packages installed."

# ============================================================
# 3. Cross-compile missing libraries
# ============================================================
TMPDIR=$(mktemp -d)
log "Working in $TMPDIR"

# Common CMake flags for Switch cross-compilation
SWITCH_CMAKE_FLAGS=(
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
    -DCMAKE_INSTALL_PREFIX="$SWITCH_PREFIX"
    -DCMAKE_BUILD_TYPE=Release
)

# --- nlohmann_json (header-only) ---
if [ ! -f "$SWITCH_PREFIX/include/nlohmann/json.hpp" ]; then
    log "Installing nlohmann_json..."
    cd "$TMPDIR"
    curl -sL https://github.com/nlohmann/json/archive/refs/tags/v3.11.3.tar.gz | tar xz
    cd json-3.11.3
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" -DJSON_BuildTests=OFF
    cmake --build build
    sudo cmake --install build
    log "nlohmann_json installed."
else
    log "nlohmann_json already installed, skipping."
fi

# --- libzip ---
if [ ! -f "$SWITCH_PREFIX/lib/libzip.a" ]; then
    log "Installing libzip..."
    cd "$TMPDIR"
    curl -sL https://github.com/nih-at/libzip/archive/refs/tags/v1.10.1.tar.gz | tar xz
    cd libzip-1.10.1
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TOOLS=OFF \
        -DBUILD_REGRESS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_DOC=OFF \
        -DENABLE_BZIP2=OFF \
        -DENABLE_LZMA=OFF \
        -DENABLE_ZSTD=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    log "libzip installed."
else
    log "libzip already installed, skipping."
fi

# --- fmt ---
if [ ! -f "$SWITCH_PREFIX/lib/libfmt.a" ]; then
    log "Installing fmt..."
    cd "$TMPDIR"
    curl -sL https://github.com/fmtlib/fmt/archive/refs/tags/10.2.1.tar.gz | tar xz
    cd fmt-10.2.1
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" \
        -DFMT_DOC=OFF -DFMT_TEST=OFF -DFMT_FUZZ=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    log "fmt installed."
else
    log "fmt already installed, skipping."
fi

# --- spdlog (header-only, Switch has no fileno/isatty) ---
if [ ! -f "$SWITCH_PREFIX/include/spdlog/spdlog.h" ]; then
    log "Installing spdlog (header-only)..."
    cd "$TMPDIR"
    curl -sL https://github.com/gabime/spdlog/archive/refs/tags/v1.14.1.tar.gz | tar xz
    sudo cp -r spdlog-1.14.1/include/spdlog "$SWITCH_PREFIX/include/"
    log "spdlog installed."
else
    log "spdlog already installed, skipping."
fi

# --- libogg ---
if [ ! -f "$SWITCH_PREFIX/lib/libogg.a" ]; then
    log "Installing libogg..."
    cd "$TMPDIR"
    curl -sL https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz | tar xz
    cd libogg-1.3.5
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    log "libogg installed."
else
    log "libogg already installed, skipping."
fi

# --- opus ---
if [ ! -f "$SWITCH_PREFIX/lib/libopus.a" ]; then
    log "Installing opus..."
    cd "$TMPDIR"
    curl -sL https://github.com/xiph/opus/releases/download/v1.4/opus-1.4.tar.gz | tar xz
    cd opus-1.4
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" \
        -DBUILD_SHARED_LIBS=OFF -DOPUS_BUILD_TESTING=OFF -DOPUS_BUILD_PROGRAMS=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    log "opus installed."
else
    log "opus already installed, skipping."
fi

# --- libvorbis ---
if [ ! -f "$SWITCH_PREFIX/lib/libvorbis.a" ]; then
    log "Installing libvorbis..."
    cd "$TMPDIR"
    curl -sL https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz | tar xz
    cd libvorbis-1.3.7
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
        -DOGG_INCLUDE_DIR="$SWITCH_PREFIX/include" \
        -DOGG_LIBRARY="$SWITCH_PREFIX/lib/libogg.a"
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    log "libvorbis installed."
else
    log "libvorbis already installed, skipping."
fi

# --- opusfile ---
if [ ! -f "$SWITCH_PREFIX/lib/libopusfile.a" ]; then
    log "Installing opusfile..."
    cd "$TMPDIR"
    curl -sL https://github.com/xiph/opusfile/releases/download/v0.12/opusfile-0.12.tar.gz | tar xz
    cd opusfile-0.12
    # opusfile uses autotools, cross-compile manually
    export CC="$AARCH64_CC"
    export CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a57 -fPIC -I$SWITCH_PREFIX/include -I$DEVKITPRO/libnx/include"
    export LDFLAGS="-L$SWITCH_PREFIX/lib"
    export PKG_CONFIG_PATH="$SWITCH_PREFIX/lib/pkgconfig"
    ./configure --host=aarch64-none-elf --prefix="$SWITCH_PREFIX" \
        --enable-static --disable-shared --disable-http --disable-examples
    make -j$(sysctl -n hw.ncpu)
    sudo make install
    unset CC CFLAGS LDFLAGS PKG_CONFIG_PATH
    log "opusfile installed."
else
    log "opusfile already installed, skipping."
fi

# --- tinyxml2 v10+ (override dkp's v6) ---
TINYXML2_VER=$(grep -r "TINYXML2_VERSION_MAJOR" "$SWITCH_PREFIX/include/tinyxml2.h" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo "0")
if [ "$TINYXML2_VER" -lt 10 ]; then
    log "Upgrading tinyxml2 to v10..."
    cd "$TMPDIR"
    curl -sL https://github.com/leethomason/tinyxml2/archive/refs/tags/10.0.0.tar.gz | tar xz
    cd tinyxml2-10.0.0
    cmake -B build "${SWITCH_CMAKE_FLAGS[@]}" \
        -DBUILD_SHARED_LIBS=OFF -Dtinyxml2_BUILD_TESTING=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    sudo cmake --install build
    # Ensure tinyxml2::tinyxml2 alias exists in cmake config
    TXML_CMAKE="$SWITCH_PREFIX/lib/cmake/tinyxml2/tinyxml2Config.cmake"
    if [ -f "$TXML_CMAKE" ] && ! grep -q "tinyxml2::tinyxml2" "$TXML_CMAKE"; then
        echo 'add_library(tinyxml2::tinyxml2 ALIAS tinyxml2)' | sudo tee -a "$TXML_CMAKE" > /dev/null
    fi
    log "tinyxml2 upgraded."
else
    log "tinyxml2 v10+ already installed, skipping."
fi

# ============================================================
# 4. Patch Switch.cmake for WHOLE_ARCHIVE support
# ============================================================
if ! grep -q "WHOLE_ARCHIVE" "$TOOLCHAIN" 2>/dev/null; then
    log "Patching Switch.cmake for WHOLE_ARCHIVE support..."
    sudo cp "$TOOLCHAIN" "$TOOLCHAIN.bak"
    # Add WHOLE_ARCHIVE linker flag support
    echo '
# WHOLE_ARCHIVE support for Switch
set(CMAKE_C_LINK_LIBRARY_USING_WHOLE_ARCHIVE "-Wl,--whole-archive" "<LINK_ITEM>" "-Wl,--no-whole-archive" CACHE STRING "")
set(CMAKE_CXX_LINK_LIBRARY_USING_WHOLE_ARCHIVE "-Wl,--whole-archive" "<LINK_ITEM>" "-Wl,--no-whole-archive" CACHE STRING "")
set(CMAKE_C_LINK_LIBRARY_USING_WHOLE_ARCHIVE_SUPPORTED TRUE CACHE BOOL "")
set(CMAKE_CXX_LINK_LIBRARY_USING_WHOLE_ARCHIVE_SUPPORTED TRUE CACHE BOOL "")' | sudo tee -a "$TOOLCHAIN" > /dev/null
    log "Switch.cmake patched."
else
    log "Switch.cmake already patched, skipping."
fi

# ============================================================
# 5. Mesa GLSL fix (important!)
# ============================================================
warn "Mesa 20.1.0 has a GLSL bug that crashes on Switch (1D texture builtins in GLES mode)."
warn "If the game crashes on boot, you need to rebuild Mesa from source."
warn "See: tools/switch/README.md for Mesa rebuild instructions."

# ============================================================
# Cleanup
# ============================================================
rm -rf "$TMPDIR"

echo ""
log "All dependencies installed!"
echo ""
echo "Next steps:"
echo "  export DEVKITPRO=/opt/devkitpro"
echo "  export PATH=\"\${DEVKITPRO}/tools/bin:\${PATH}\""
echo "  cmake -H. -Bbuild-switch -GNinja -DCMAKE_TOOLCHAIN_FILE=\$DEVKITPRO/cmake/Switch.cmake -DUSE_OPENGLES=ON"
echo "  cmake --build build-switch --target soh_nro"
echo ""
