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

## Pitfalls We Encountered (踩过的坑)

### Build Environment

- **Every new terminal** needs `export DEVKITPRO=/opt/devkitpro && export PATH="${DEVKITPRO}/tools/bin:${PATH}"`. Without this, CMake cannot find the Switch toolchain.
- **spdlog cannot be compiled** for Switch — `fileno()` and `isatty()` don't exist on Switch libnx. Must install as header-only.
- **dkp-pacman's tinyxml2 is v6**, but SoH 9.x requires v10+. The setup script cross-compiles v10 and overwrites the old version.
- **tinyxml2 CMake target name**: SoH expects `tinyxml2::tinyxml2` but the installed config only defines `tinyxml2`. The setup script adds an alias to `tinyxml2Config.cmake`.
- **opusfile uses autotools**, not CMake — requires manual cross-compile with `--host=aarch64-none-elf` and explicit `CC`/`CFLAGS`.
- **`Switch.cmake` lacks `WHOLE_ARCHIVE` support** — linker errors for static libraries that need whole-archive linking. The setup script patches this.

### Mesa / Graphics

- **Mesa 20.1.0 GLSL crash** is the most critical issue. The game compiles fine but crashes immediately on Switch boot. Root cause: `builtin_builder::create_builtins()` creates 1D texture sampler functions which don't exist in GLES, causing a null pointer dereference. You MUST rebuild Mesa with the 1D sampler guard fix.
- **GCC 15.2 breaks Mesa build**: `threads.h` has `_ISOC11_SOURCE` / `timespec_get` conflicts, and `threads_posix.h` uses `pthread_mutex_timedlock` which Switch doesn't support. Both need manual fixes.
- **Mesa cross-compilation** requires a Meson cross-file with `-DHAVE_PTHREAD` and manually specified paths. Also needs `brew install meson` and `pip3 install mako`.
- **glewInit() must be skipped** on Switch — it uses Mesa's native GL, not GLEW. The `#if !defined(__SWITCH__)` guard in `gfx_opengl.cpp` handles this.
- **SDL2 must use OpenGL ES 3.0** context (not desktop GL 4.1). The `gfx_sdl2.cpp` change sets `SDL_GL_CONTEXT_PROFILE_ES` with version 3.0.

### C/C++ Compilation

- **`void*` implicit cast errors**: Switch toolchain uses stricter C standards. `idle.c` and `TwoHeadArena.c` need explicit `(void*)` casts (5 places in TwoHeadArena alone).
- **`-Wno-int-conversion`** needed in `soh/CMakeLists.txt` for Switch — some legacy N64 code uses implicit int-to-pointer conversions.

### ROM and Assets

- **Only NTSC 1.0 US ROM works** with SoH 9.x. PAL ROMs can extract assets (`oot.otr`) but the game crashes on Switch.
- **SoH uses CRC32C (Castagnoli)** for ROM verification, not standard CRC32. Don't confuse them.
- **ROM format matters**: must be `.z64` (big-endian, starts with `0x80`). If your ROM starts with `0x37` (v64) or `0x40` (n64), byte-swap it first.
- **ExtractAssets must run on host machine** (macOS/Linux native build), not the Switch cross-build. Build the host version first with `cmake -H. -Bbuild-cmake -GNinja`.
- **HD texture mods** (like OoT Reloaded) go in `/switch/soh/mods/` as `.o2r` files.

### Chinese Language Support

- **iQue ROM does NOT work** for Chinese text extraction. iQue textIds are based on the GameCube version and don't align with NTSC 1.0. Use the 3DS OoT 3D Simplified Chinese version instead.
- **`sChiMessageEntryTablePtr` must be `extern "C"`**, NOT `static`. The actual global is defined in `z_message_PAL.c:53`. If you declare it as `static` in `z_message_CHI.cpp`, the Chinese option won't appear in the settings menu.
- **MessageTableEntry has 4 fields**, not 5. Pack type and ypos: `typePos = (type << 4) | (yPos & 0xF)`.
- **Chinese character encoding uses 3 bytes**: `0x03 + high + low`. Earlier versions used 2-byte encoding (`>= 0xA0`), but this conflicted with NES icon bytes `0x9F-0xAB` (button icons like A, B, C↑, etc.), causing icons to display as garbled Chinese characters.
- **Language arrays throughout the codebase** must be expanded from 4 to 5 elements when adding Chinese. This affects ~20 texture/string arrays in `z_kaleido_scope_PAL.c`, `z_file_choose.c`, `z_file_nameset_PAL.c`, `z_parameter.c`, and `BossRush.cpp`. Missing even one causes array-out-of-bounds crashes.

### Deployment

- **Full memory mode required** for hbmenu: hold R while tapping a game on the home screen. Without this, the NRO won't have enough memory and will crash.
- **NSP forwarder** can bypass the need for full memory mode — install a forwarder NSP via Tinfoil to launch directly from the home screen.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Switch.cmake` not found | Install switch-dev: `sudo dkp-pacman -S switch-dev` |
| `tinyxml2::tinyxml2` not found | Run setup script — it upgrades tinyxml2 and adds the alias |
| GLSL crash on boot | Rebuild Mesa (see above) |
| `fileno`/`isatty` errors | spdlog must be header-only, not compiled |
| `void*` cast errors | Add explicit `(void*)` casts in `idle.c` and `TwoHeadArena.c` |
| Linker errors with static libs | Ensure `Switch.cmake` is patched for `WHOLE_ARCHIVE` |
| Game crashes with PAL ROM | Use NTSC 1.0 US ROM only |
| Wrong ROM format (v64/n64) | Byte-swap to z64 format (must start with `0x80`) |
| Game assets not loading | Make sure `oot.o2r` and `soh.o2r` are in the same directory as `soh.nro` |
| NRO crashes on launch | Use full memory mode (hold R while opening a game) |
| No Chinese option in menu | Verify `z_message_CHI.cpp` is compiled in; check `sChiMessageEntryTablePtr` is `extern`, not `static` |
| Chinese shows as ??? | Missing CJK glyphs — run `generate_font_glyphs.py` with expanded charmap |
| Button icons show as garbled text | Chinese encoding must use 3-byte `0x03` prefix, not 2-byte `>= 0xA0` |
| Shop entry crashes | Check QM→NES EVENT control code mapping |
| Shop has no choices on page 2 | Check TWO_CHOICE/THREE_CHOICE mapping (must consume FFFF padding) |
