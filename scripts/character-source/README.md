# Dexter character sheet pipeline

Source sheet (not shipped in the app bundle):

- `dexter_character_sheet.jpg` — 4×2 grid of canonical Dexter states

Regenerate production PNGs + Xcode imagesets:

```bash
pip3 install pillow numpy
python3 scripts/character-source/process_dexter_character_sheet.py
```

Outputs:

- `scripts/character-source/output/DexterCharacter*.png` (1024×1024, RGBA)
- `leanring-buddy/Assets.xcassets/DexterCharacter*.imageset/`

Background removal: luminance + low-saturation keying tuned for the sheet’s dark/neutral backdrop; colored props (headphones, stars, bubbles) are preserved by saturation guard.

Manual art pass may still be needed for hair-edge halos on some states.
