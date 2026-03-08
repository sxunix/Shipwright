# Building SoH 9.x for Nintendo Switch

## Prerequisites

- macOS (Apple Silicon or Intel) or Linux
- [devkitPro](https://devkitpro.org/) installed at `/opt/devkitpro`
- CMake 3.20+, Ninja (recommended)
- A supported OoT ROM (NTSC 1.0 US)

## Step 1: Install Dependencies

Run the dependency setup script (requires `sudo` for installing to devkitPro):

```bash
./tools/switch/setup_switch_deps.sh
```

This installs:

| Package | Source | Notes |
|---------|--------|-------|
| switch-dev, switch-sdl2, switch-mesa, etc. | dkp-pacman | Base Switch development packages |
| nlohmann_json | Header-only | JSON parsing |
| libzip | Cross-compiled | ZIP/O2R archive support |
| fmt 10.2.1 | Cross-compiled | String formatting |
| spdlog 1.14.1 | Header-only | Logging (Switch lacks fileno/isatty) |
| libogg, opus, libvorbis, opusfile | Cross-compiled | Audio playback |
| tinyxml2 v10+ | Cross-compiled | Replaces dkp's outdated v6 |

The script also patches `Switch.cmake` for `WHOLE_ARCHIVE` linker support.

## Step 2: Build

```bash
export DEVKITPRO=/opt/devkitpro
export PATH="${DEVKITPRO}/tools/bin:${PATH}"

# Clone with submodules
git clone --recursive -b switch-chinese https://github.com/sxunix/Shipwright.git
cd Shipwright

# Install dependencies
./tools/switch/setup_switch_deps.sh

# Configure and build
cmake -H. -Bbuild-switch -GNinja \
  -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/Switch.cmake \
  -DUSE_OPENGLES=ON
cmake --build build-switch --target soh_nro
```

Output: `build-switch/soh/soh.nro` (~37MB)

## Step 3: Generate Game Assets

You need to build the asset extractor on your host machine first:

```bash
# Host build (macOS/Linux native)
cmake -H. -Bbuild-cmake -GNinja
cmake --build build-cmake --target ExtractAssets

# Extract assets from your ROM
# This generates oot.o2r and soh.o2r
```

## Step 4: Deploy to Switch

Copy to SD card:

```
/switch/soh/
├── soh.nro          ← from build-switch/soh/
├── oot.o2r          ← from build-cmake/ (extracted from your ROM)
└── soh.o2r          ← from build-cmake/soh/
```

Launch via Homebrew Menu (hold R while opening a game), or create an [NSP forwarder](https://nsp-forwarder.n8.io/) for home screen access.

## Mesa GLSL Fix

Switch's `switch-mesa` (20.1.0) has a bug: the GLSL compiler crashes when creating 1D texture builtin functions in GLES 3.0 mode. If the game crashes on boot, you need to rebuild Mesa from source.

### How to fix

1. Download Mesa 20.1.0-rc3 source from GitLab
2. Apply the devkitPro patch (`switch-mesa-20.1.0-5.patch`)
3. Fix `builtin_functions.cpp`: add `GLSL_SAMPLER_DIM_1D` guard to `_texture()`, `_textureSize()`, `_texelFetch()`, `_textureQueryLod()` — return `always_false` stub for 1D samplers
4. Fix `threads.h`/`threads_posix.h`: resolve GCC 15.2 `_ISOC11_SOURCE` and `timespec_get` conflicts; remove `pthread_mutex_timedlock` (unsupported on Switch)
5. Cross-compile with Meson (`brew install meson; pip3 install mako`)
6. Replace `.a` files in `/opt/devkitpro/portlibs/switch/lib/` (backup originals first)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Switch.cmake` not found | Install switch-dev: `sudo dkp-pacman -S switch-dev` |
| `tinyxml2::tinyxml2` not found | Run setup script — it upgrades tinyxml2 and adds the alias |
| GLSL crash on boot | Rebuild Mesa (see above) |
| `fileno`/`isatty` errors | spdlog must be header-only, not compiled |
| Game assets not loading | Make sure `oot.o2r` and `soh.o2r` are in the same directory as `soh.nro` |
| No Chinese option in menu | Verify `z_message_CHI.cpp` is compiled in; check `sChiMessageEntryTablePtr` is extern, not static |
