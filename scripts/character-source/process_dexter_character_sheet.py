#!/usr/bin/env python3
"""
Extract 8 Dexter character states from the 4×2 source sheet.
- Removes black sheet background (alpha)
- Tight bounding box + consistent scale + 1024×1024 canvas
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = (
    REPO_ROOT.parent.parent
    / ".cursor/projects/Users-vercetti-Downloads-Projects-Dexter/assets"
    / "ChatGPT_Image_Sep_25__2026_at_07_55_52_AM-1b2bfeba-5c8a-4b83-88b2-40f91b8e9a28.jpg"
)
# Fallback when run from standard repo layout
ALT_SOURCE = REPO_ROOT / "scripts/character-source/dexter_character_sheet.jpg"

ASSETS_ROOT = REPO_ROOT / "leanring-buddy/Assets.xcassets"
CANVAS = 1024
MARGIN_FRACTION = 0.06
TARGET_BODY_HEIGHT_FRACTION = 0.72  # of canvas
FOOT_BASELINE_FRACTION = 0.88  # y position of bbox bottom

STATE_NAMES = [
    "DexterCharacterIdle",
    "DexterCharacterListening",
    "DexterCharacterThinking",
    "DexterCharacterSpeaking",
    "DexterCharacterWorking",
    "DexterCharacterSuccess",
    "DexterCharacterError",
    "DexterCharacterSleeping",
]


def resolve_source_path() -> Path:
    if ALT_SOURCE.exists():
        return ALT_SOURCE
    if DEFAULT_SOURCE.exists():
        return DEFAULT_SOURCE
    raise FileNotFoundError(
        f"Source sheet not found. Copy the sheet to {ALT_SOURCE} or provide DEFAULT_SOURCE."
    )


def remove_black_background(rgba: Image.Image) -> Image.Image:
    arr = np.array(rgba.convert("RGBA"), dtype=np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3].copy()

    luminance = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    max_channel = np.max(rgb, axis=-1)
    min_channel = np.min(rgb, axis=-1)
    saturation = max_channel - min_channel

    # Sheet background: near-black or neutral dark gray (JPEG may lift blacks)
    flat_dark = (saturation < 42) & (luminance < 95)
    background_mask = flat_dark & ((max_channel < 35) | (luminance < 72))

    # Feather transition on gray spill outside the character silhouette
    edge_mask = flat_dark & (luminance < 110) & ~background_mask
    edge_strength = np.clip((110 - luminance) / 110.0, 0, 1)

    alpha[background_mask] = 0
    alpha[edge_mask] = np.minimum(alpha[edge_mask], 255 * (1 - edge_strength[edge_mask] * 0.92))

    # Preserve colored glows (purple headphones, yellow stars) — never key out saturated pixels
    alpha[saturation > 55] = np.maximum(alpha[saturation > 55], arr[..., 3][saturation > 55])

    alpha[alpha < 10] = 0

    arr[..., 3] = alpha
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def tight_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    arr = np.array(image)
    ys, xs = np.where(arr[..., 3] > 8)
    if len(xs) == 0:
        return 0, 0, image.width, image.height
    pad = max(4, int(min(image.width, image.height) * 0.02))
    left = max(0, int(xs.min()) - pad)
    right = min(image.width, int(xs.max()) + pad + 1)
    top = max(0, int(ys.min()) - pad)
    bottom = min(image.height, int(ys.max()) + pad + 1)
    return left, top, right, bottom


def split_grid(image: Image.Image, cols: int = 4, rows: int = 2) -> list[Image.Image]:
    width, height = image.size
    cells: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            left = int(col * width / cols)
            right = int((col + 1) * width / cols)
            top = int(row * height / rows)
            bottom = int((row + 1) * height / rows)
            # inset 1% to avoid neighbor bleed
            inset_x = int((right - left) * 0.02)
            inset_y = int((bottom - top) * 0.02)
            cell = image.crop(
                (left + inset_x, top + inset_y, right - inset_x, bottom - inset_y)
            )
            cells.append(cell)
    return cells


def normalize_to_canvas(images: list[Image.Image]) -> list[Image.Image]:
    processed: list[Image.Image] = []
    bboxes = []
    for img in images:
        cut = remove_black_background(img.convert("RGBA"))
        bbox = tight_bbox(cut)
        cropped = cut.crop(bbox)
        processed.append(cropped)
        bboxes.append(cropped.size)

    # Unified scale from median character height
    heights = [h for _, h in bboxes]
    target_height = int(CANVAS * TARGET_BODY_HEIGHT_FRACTION)
    median_h = float(np.median(heights))
    scale = target_height / median_h

    canvases: list[Image.Image] = []
    for cropped in processed:
        new_w = max(1, int(cropped.width * scale))
        new_h = max(1, int(cropped.height * scale))
        resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        x = (CANVAS - new_w) // 2
        foot_y = int(CANVAS * FOOT_BASELINE_FRACTION)
        y = foot_y - new_h
        y = max(int(CANVAS * MARGIN_FRACTION), min(y, CANVAS - new_h - int(CANVAS * MARGIN_FRACTION)))
        canvas.alpha_composite(resized, (x, y))
        canvases.append(canvas)
    return canvases


def write_imageset(name: str, png_path: Path) -> None:
    imageset_dir = ASSETS_ROOT / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)
    dest = imageset_dir / f"{name}.png"
    shutil.copy2(png_path, dest)
    contents = {
        "images": [{"filename": dest.name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    (imageset_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def verify_png(path: Path) -> dict:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    alpha = arr[..., 3]
    opaque = alpha > 200
    return {
        "size": img.size,
        "has_transparency": bool(np.any(alpha < 250)),
        "opaque_pixels": int(np.sum(opaque)),
        "fully_transparent_corners": all(
            alpha[y, x] < 10
            for y, x in [(0, 0), (0, img.width - 1), (img.height - 1, 0), (img.height - 1, img.width - 1)]
        ),
    }


def main() -> None:
    source = resolve_source_path()
    print(f"Source: {source}")
    sheet = Image.open(source).convert("RGB")
    cells = split_grid(sheet)
    if len(cells) != 8:
        raise RuntimeError(f"Expected 8 cells, got {len(cells)}")

    output_dir = REPO_ROOT / "scripts/character-source/output"
    output_dir.mkdir(parents=True, exist_ok=True)

    normalized = normalize_to_canvas(cells)
    for name, canvas in zip(STATE_NAMES, normalized):
        out_path = output_dir / f"{name}.png"
        canvas.save(out_path, "PNG")
        write_imageset(name, out_path)
        stats = verify_png(out_path)
        print(f"{name}: {stats}")

    print("Done. Imagesets written under Assets.xcassets/")


if __name__ == "__main__":
    main()
