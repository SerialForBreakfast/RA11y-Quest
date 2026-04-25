#!/usr/bin/env python3
"""
Materialize Banishment imagesets from ``memlog/requirements/Design/MockupScreens`` PNGs.

Mockups are **1376×768** landscape composites (device chrome + in-screen art). This script:

1. Crops the **inner LCD region** (fractions in ``MOCKUP_INNER_SCREEN_LTRB`` — tune if a new mockup revision shifts the frame).
2. Writes **portrait RGB masters** ``2048×4096`` for ward/tower backgrounds (cover-fit) — required by
   ``utility/qa_banishment_png_assets.py`` and ``iOSBanishmentQuestView`` heuristics.
3. Writes **1024×1024 RGBA** sprites for ring, creatures, flare, and dark anchor (cover-fit).
4. Writes hub icon **1376×768 RGBA** from the ward mockup inner screen.

**Canonical command** (repo root)::

    python3 utility/import_banishment_mockups_to_assets.py

**Do not** ship Banishment art from ``banishment_procedural_placeholder.py`` unless you are intentionally
using greybox fallbacks — it does not match design mockups.

``banishment_gesture_z_reference`` is optional and is **not** overwritten here (avoid junk crops);
generate separately if needed.

Requires Pillow.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

REPO = Path(__file__).resolve().parent.parent
MOCKUP_DIR = REPO / "memlog/requirements/Design/MockupScreens"
ASSETS = REPO / "RA11y-iOS/RA11y-iOS/Assets.xcassets"

BG_W, BG_H = 2048, 4096
SPRITE = 1024
HUB_W, HUB_H = 1376, 768

# Normalized inner screen within mockup canvas (left, top, right, bottom), 0..1.
# Tuned for banishment_iphone_* v01; adjust when replacing mockup masters.
MOCKUP_INNER_SCREEN_LTRB = (0.172, 0.058, 0.828, 0.942)

CONTENTS_TEMPLATE = {
    "images": [{"filename": None, "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1},
}


def extract_inner_screen(im: Image.Image) -> Image.Image:
    w, h = im.size
    l, t, r, b = MOCKUP_INNER_SCREEN_LTRB
    return im.crop((int(w * l), int(h * t), int(w * r), int(h * b)))


def fit_portrait_master_rgb(im: Image.Image) -> Image.Image:
    return ImageOps.fit(im.convert("RGB"), (BG_W, BG_H), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def fit_square_rgba(
    im: Image.Image,
    size: int = SPRITE,
    centering: tuple[float, float] = (0.5, 0.5),
) -> Image.Image:
    return ImageOps.fit(im.convert("RGBA"), (size, size), method=Image.Resampling.LANCZOS, centering=centering)


def creature_sprite_from_beat(inner_screen: Image.Image, *, bottom_card_trim: float = 0.30) -> Image.Image:
    """
    Threat illustration + seal: upper portion of inner screen, excluding the bottom instruction card.

    - ``bottom_card_trim``: fraction of inner height removed from the bottom (card + safe margin).
    """
    iw, ih = inner_screen.size
    cut = int(ih * (1.0 - bottom_card_trim))
    crop = inner_screen.crop((0, 0, iw, max(32, cut)))
    return fit_square_rgba(crop, centering=(0.5, 0.42))


def ward_ring_sprite(ward_inner: Image.Image) -> Image.Image:
    iw, ih = ward_inner.size
    side = int(min(iw, ih) * 0.56)
    cx, cy = iw // 2, int(ih * 0.36)
    x0 = max(0, cx - side // 2)
    y0 = max(0, cy - side // 2)
    x1 = min(iw, x0 + side)
    y1 = min(ih, y0 + side)
    region = ward_inner.crop((x0, y0, x1, y1))
    return fit_square_rgba(region, centering=(0.5, 0.5))


def flare_sprite(inner_banished: Image.Image) -> Image.Image:
    iw, ih = inner_banished.size
    side = int(min(iw, ih) * 0.58)
    cx, cy = iw // 2, ih // 2
    x0 = max(0, cx - side // 2)
    y0 = max(0, cy - side // 2)
    region = inner_banished.crop((x0, y0, x0 + side, y0 + side))
    return fit_square_rgba(region, centering=(0.5, 0.5))


def dark_anchor_sprite(dark_inner: Image.Image) -> Image.Image:
    iw, ih = dark_inner.size
    x0, x1 = int(iw * 0.06), int(iw * 0.94)
    y0, y1 = int(ih * 0.10), int(ih * 0.78)
    region = dark_inner.crop((x0, y0, x1, y1))
    return fit_square_rgba(region, centering=(0.5, 0.45))


def hub_icon_from_ward(ward_im: Image.Image) -> Image.Image:
    inner = extract_inner_screen(ward_im)
    return ImageOps.fit(inner.convert("RGBA"), (HUB_W, HUB_H), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def write_imageset(stem: str, png_name: str, image: Image.Image) -> None:
    d = ASSETS / f"{stem}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    out_png = d / png_name
    image.save(out_png, format="PNG", optimize=True)
    payload = json.loads(json.dumps(CONTENTS_TEMPLATE))
    payload["images"][0]["filename"] = png_name
    (d / "Contents.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out_png.relative_to(REPO)}")


def main() -> None:
    if not MOCKUP_DIR.is_dir():
        print(f"error: missing mockups: {MOCKUP_DIR}", file=sys.stderr)
        raise SystemExit(1)
    if not ASSETS.is_dir():
        print(f"error: missing Assets: {ASSETS}", file=sys.stderr)
        raise SystemExit(1)

    paths = {
        "ward": MOCKUP_DIR / "banishment_iphone_ward_v01.png",
        "skeleton": MOCKUP_DIR / "banishment_iphone_skeleton_v01.png",
        "orc": MOCKUP_DIR / "banishment_iphone_orc_v01.png",
        "troll": MOCKUP_DIR / "banishment_iphone_troll_v01.png",
        "dark": MOCKUP_DIR / "banishment_iphone_dark_v01.png",
        "banished": MOCKUP_DIR / "banishment_iphone_banished_v03.png",
    }
    for p in paths.values():
        if not p.is_file():
            print(f"error: missing mockup: {p}", file=sys.stderr)
            raise SystemExit(1)

    ward = Image.open(paths["ward"])
    skeleton = Image.open(paths["skeleton"])
    orc = Image.open(paths["orc"])
    troll = Image.open(paths["troll"])
    dark = Image.open(paths["dark"])
    banished = Image.open(paths["banished"])

    ward_i = extract_inner_screen(ward)
    sk_i = extract_inner_screen(skeleton)
    orc_i = extract_inner_screen(orc)
    tr_i = extract_inner_screen(troll)
    dark_i = extract_inner_screen(dark)
    ban_i = extract_inner_screen(banished)

    write_imageset("banishment_ward_bg", "banishment_ward_bg.png", fit_portrait_master_rgb(ward_i))
    write_imageset("banishment_tower_bg", "banishment_tower_bg.png", fit_portrait_master_rgb(sk_i))

    write_imageset("banishment_ward_ring", "banishment_ward_ring.png", ward_ring_sprite(ward_i))
    write_imageset("banishment_goblin", "banishment_goblin.png", creature_sprite_from_beat(ward_i))
    write_imageset("banishment_skeleton", "banishment_skeleton.png", creature_sprite_from_beat(sk_i))
    write_imageset("banishment_orc", "banishment_orc.png", creature_sprite_from_beat(orc_i))
    write_imageset("banishment_troll", "banishment_troll.png", creature_sprite_from_beat(tr_i))
    write_imageset(
        "banishment_dragon",
        "banishment_dragon.png",
        creature_sprite_from_beat(dark_i, bottom_card_trim=0.34),
    )
    write_imageset("banishment_flare_escape", "banishment_flare_escape.png", flare_sprite(ban_i))
    write_imageset("banishment_dark_anchor", "banishment_dark_anchor.png", dark_anchor_sprite(dark_i))

    write_imageset("banishment_hub_icon", "banishment_hub_icon.png", hub_icon_from_ward(ward))

    print(f"Done — mockup-derived Banishment assets under {ASSETS}")
    print("Next: python3 utility/qa_banishment_png_assets.py && bash utility/validate_banishment_assets.sh")


if __name__ == "__main__":
    main()
