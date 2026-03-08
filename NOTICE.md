# Third-Party Content Notice

This fork contains the following files with third-party copyrighted content.
These files are required for compilation and cannot be moved from their current locations.

## Files Containing Third-Party Content

| File | Source | Copyright Holder | Notes |
|------|--------|-----------------|-------|
| `soh/soh/z_message_CHI.cpp` | 3DS *Ocarina of Time 3D* Simplified Chinese translation | Nintendo / Grezzo | 2116 messages converted from QM format to NES byte arrays |
| `soh/src/code/z_kanfont_chinese_data.c` | Rendered from STHeiti Medium font | Apple Inc. | 2161 CJK glyphs (16×16 I4 format, 276KB) |

## How to Regenerate These Files Yourself

If you prefer to generate these files from your own legally obtained sources:

### z_message_CHI.cpp
```bash
# 1. Extract QM data from your own 3DS OoT3D ROM
# 2. Run the converter
cd tools/chinese
python qm_to_nes_v8.py
# 3. Copy output to soh/soh/z_message_CHI.cpp
```

### z_kanfont_chinese_data.c
```bash
# Use any CJK font you have a license for (e.g., Noto Sans CJK)
cd tools/chinese
python generate_font_glyphs.py \
  --font /path/to/your/CJKFont.ttf \
  --charmap charmap_chn.txt \
  --output-dir ./output/
# Copy output to soh/src/code/z_kanfont_chinese_data.c
```

## Other Content

All other files in this fork (source code modifications, build scripts, tools, documentation, and the 139 hand-translated icon messages in `translations/`) are original work and do not contain third-party copyrighted content.

This project follows the same approach as the upstream [Ship of Harkinian](https://github.com/HarbourMasters/Shipwright) project, which also includes game message data and font assets derived from the original N64 title.
