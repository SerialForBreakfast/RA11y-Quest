#!/usr/bin/env python3
"""
Resize and copy **already-generated** Banishment PNGs (e.g. from Cursor image export) into
``Assets.xcassets``. This does not create art — it only fits pixels to catalog spec.

Expected filenames in ``--source-dir``::

  banishment_ward_bg_gen.png
  banishment_tower_bg_gen.png
  banishment_threat_{goblin,skeleton,orc,troll,dragon}_gen.png
  banishment_ward_ring_gen.png
  banishment_flare_escape_gen.png
  banishment_dark_anchor_gen.png
  banishment_hub_icon_gen.png

Usage::

    python3 utility/ingest_llm_banishment_pngs.py --source-dir /path/to/assets

Requires Pillow.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "RA11y-iOS/RA11y-iOS/Assets.xcassets"
BG_SIZE = (2048, 4096)
SPRITE_SIZE = (1024, 1024)
HUB_SIZE = (1376, 768)


def fit_rgb(path: Path, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGB"), size, Image.Resampling.LANCZOS)


def fit_rgba(path: Path, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGBA"), size, Image.Resampling.LANCZOS)


def write_png(stem: str, image: Image.Image) -> None:
    d = ASSETS / f"{stem}.imageset"
    if not d.is_dir():
        print(f"error: missing imageset dir: {d}", file=sys.stderr)
        raise SystemExit(1)
    out = d / f"{stem}.png"
    image.save(out, format="PNG", optimize=True)
    print(f"wrote {out.relative_to(REPO)}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", type=Path, required=True)
    args = p.parse_args()
    src: Path = args.source_dir.resolve()
    if not src.is_dir():
        print(f"error: not a directory: {src}", file=sys.stderr)
        raise SystemExit(1)

    write_png("banishment_ward_bg", fit_rgb(src / "banishment_ward_bg_gen.png", BG_SIZE))
    write_png("banishment_tower_bg", fit_rgb(src / "banishment_tower_bg_gen.png", BG_SIZE))
    for creature in ("goblin", "skeleton", "orc", "troll", "dragon"):
        write_png(f"banishment_threat_{creature}", fit_rgba(src / f"banishment_threat_{creature}_gen.png", SPRITE_SIZE))
    write_png("banishment_ward_ring", fit_rgba(src / "banishment_ward_ring_gen.png", SPRITE_SIZE))
    write_png("banishment_flare_escape", fit_rgba(src / "banishment_flare_escape_gen.png", SPRITE_SIZE))
    write_png("banishment_dark_anchor", fit_rgba(src / "banishment_dark_anchor_gen.png", SPRITE_SIZE))
    write_png("banishment_hub_icon", fit_rgba(src / "banishment_hub_icon_gen.png", HUB_SIZE))
    print("Done. Run: python3 utility/qa_banishment_png_assets.py")


if __name__ == "__main__":
    main()
