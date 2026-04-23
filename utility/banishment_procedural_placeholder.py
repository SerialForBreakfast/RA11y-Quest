#!/usr/bin/env python3
"""
**Legacy only** — procedural gradients / blobs, not mockup fidelity.

Canonical art path: ``memlog/requirements/Design/MockupScreens/*.png`` →
``utility/import_banishment_mockups_to_assets.py``.

Usage (repo root)::

    python3 utility/banishment_procedural_placeholder.py

Requires Pillow.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "RA11y-iOS/RA11y-iOS/Assets.xcassets"

# Spec: portrait masters
BG_W, BG_H = 2048, 4096
SPRITE = 1024
HUB_W, HUB_H = 1376, 768

# Torchlit dungeon palette (approximate RA11y mockup mood)
SLATE_TOP = (28, 32, 52)
UMBER_MID = (42, 28, 38)
AMBER_GLOW = (180, 120, 55)
DEEP_SHADOW = (12, 10, 18)
GOLD = (235, 190, 95)
VIOLET_CRACK = (120, 80, 160)


def _lerp_rgb(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    im = Image.new("RGB", size)
    px = im.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        rgb = _lerp_rgb(top, bottom, t)
        for x in range(w):
            px[x, y] = rgb
    return im


def _soft_vignette(rgb: Image.Image, strength: float = 0.45) -> Image.Image:
    w, h = rgb.size
    overlay = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(overlay)
    cx, cy = w // 2, h // 2
    max_r = int(math.hypot(cx, cy) * 1.05)
    for i in range(40):
        t = i / 39.0
        r = int(max_r * (0.35 + 0.65 * t))
        alpha = int(255 * strength * (t**1.8))
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    inv = Image.eval(overlay, lambda p: 255 - p)
    dark = Image.new("RGB", (w, h), DEEP_SHADOW)
    return Image.composite(dark, rgb, inv)


def generate_ward_bg() -> Image.Image:
    base = _vertical_gradient((BG_W, BG_H), SLATE_TOP, UMBER_MID)
    base = _soft_vignette(base, 0.38)
    dr = ImageDraw.Draw(base, "RGB")
    # Suggest stone arch / gate — warm center
    cx, cy = BG_W // 2, int(BG_H * 0.38)
    for i in range(6):
        t = i / 5.0
        r = int(BG_W * (0.22 + t * 0.12))
        a = int(25 + 35 * (1 - t))
        gold = tuple(min(255, c + 40) for c in AMBER_GLOW)
        dr.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], outline=(*gold, a)[:3], width=6)
    # Floor hint
    dr.rectangle([0, int(BG_H * 0.72), BG_W, BG_H], fill=_lerp_rgb(UMBER_MID, DEEP_SHADOW, 0.55))
    return base


def generate_tower_bg() -> Image.Image:
    """Vertical shaft readable at phone scale — stronger structure than a flat gradient (avoids “broken” tiny PNGs)."""
    top = (14, 18, 34)
    bottom = (52, 36, 48)
    base = _vertical_gradient((BG_W, BG_H), top, bottom)
    base = _soft_vignette(base, 0.42)
    dr = ImageDraw.Draw(base, "RGB")
    cx = BG_W // 2

    # Receding shaft walls — staggered masonry ledges (high contrast vs ward arch).
    for row in range(14):
        y = int(BG_H * (0.12 + row * 0.052))
        inset = 38 + (row % 3) * 22
        shade = _lerp_rgb(top, bottom, 0.35 + (row % 4) * 0.08)
        dr.line([(inset, y), (BG_W - inset, y)], fill=shade, width=7)
        dr.line([(inset + 6, y + 4), (BG_W - inset - 6, y + 4)], fill=_lerp_rgb(shade, DEEP_SHADOW, 0.4), width=3)

    # Diagonal stress lines — tower torsion (distinct from ward’s elliptical gate).
    for i in range(-5, 6):
        x0 = cx + i * 85
        dr.line(
            [(x0, int(BG_H * 0.08)), (x0 + i * 14, int(BG_H * 0.94))],
            fill=_lerp_rgb(SLATE_TOP, AMBER_GLOW, 0.35),
            width=5,
        )

    # Torch pools — warm blobs on alternating sides.
    for k, side in enumerate([-1, 1, -1, 1, -1]):
        tx = cx + side * int(BG_W * (0.28 + k * 0.07))
        ty = int(BG_H * (0.22 + k * 0.14))
        for r, col in [(110, AMBER_GLOW), (64, (255, 220, 140)), (28, (255, 245, 210))]:
            dr.ellipse([tx - r, ty - r, tx + r, ty + r], fill=col)

    # Central void / curse ring — same violet family as ward but sharper ellipse.
    dr.ellipse(
        [cx - 160, int(BG_H * 0.38) - 110, cx + 160, int(BG_H * 0.38) + 110],
        outline=VIOLET_CRACK,
        width=8,
    )
    dr.ellipse(
        [cx - 90, int(BG_H * 0.38) - 64, cx + 90, int(BG_H * 0.38) + 64],
        outline=_lerp_rgb(VIOLET_CRACK, GOLD, 0.25),
        width=4,
    )

    # Floor pit falloff.
    dr.rectangle([0, int(BG_H * 0.78), BG_W, BG_H], fill=_lerp_rgb(bottom, DEEP_SHADOW, 0.65))
    return base


def _new_sprite() -> Image.Image:
    return Image.new("RGBA", (SPRITE, SPRITE), (0, 0, 0, 0))


def generate_ward_ring() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx = cy = SPRITE // 2
    r_out, r_in = int(SPRITE * 0.42), int(SPRITE * 0.24)
    for k in range(12):
        t = k / 11.0
        r = r_in + (r_out - r_in) * t
        alpha = int(55 + 200 * math.sin(t * math.pi))
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*GOLD, min(255, alpha)), width=max(8, int(12 - k * 0.4)))
    dr.ellipse([cx - r_in + 6, cy - r_in + 6, cx + r_in - 6, cy + r_in - 6], outline=(*VIOLET_CRACK, 140), width=4)
    return im.filter(ImageFilter.GaussianBlur(radius=0.6))


def _blob(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill: tuple[int, int, int, int]) -> None:
    draw.polygon([(int(p[0]), int(p[1])) for p in pts], fill=fill)


def _scale_pts(cx: float, cy: float, mag: float, pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [(cx + (x - cx) * mag, cy + (y - cy) * mag) for x, y in pts]


def generate_threat_goblin() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, int(SPRITE * 0.52)
    mag = 1.52

    def T(x: float, y: float) -> tuple[float, float]:
        return (cx + (x - cx) * mag, cy + (y - cy) * mag)

    # Hunched body (scaled up for small-target readability)
    _blob(
        dr,
        [
            T(cx - 55, cy + 40),
            T(cx - 70, cy - 10),
            T(cx - 35, cy - 85),
            T(cx + 25, cy - 80),
            T(cx + 65, cy - 15),
            T(cx + 50, cy + 45),
            T(cx, cy + 55),
        ],
        (75, 120, 85, 255),
    )
    dr.polygon([T(cx - 50, cy - 70), T(cx - 85, cy - 120), T(cx - 30, cy - 85)], fill=(55, 90, 60, 255))
    dr.polygon([T(cx + 35, cy - 75), T(cx + 80, cy - 115), T(cx + 55, cy - 78)], fill=(55, 90, 60, 255))
    dr.ellipse([T(cx - 28, cy - 45), T(cx - 12, cy - 28)], fill=(255, 200, 80, 255))
    dr.ellipse([T(cx + 12, cy - 45), T(cx + 28, cy - 28)], fill=(255, 200, 80, 255))
    return im


def generate_threat_skeleton() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, SPRITE // 2
    mag = 1.25
    top = int(SPRITE * 0.16)

    def T(x: float, y: float) -> tuple[float, float]:
        return (cx + (x - cx) * mag, cy + (y - cy) * mag)

    s0, s1 = T(cx - 44, float(top)), T(cx + 44, float(top + 76))
    dr.rounded_rectangle(
        [int(s0[0]), int(s0[1]), int(s1[0]), int(s1[1])],
        radius=26,
        fill=(210, 205, 195, 255),
    )
    t0, t1 = T(cx - 30, float(top + 62)), T(cx + 30, float(SPRITE * 0.76))
    dr.rectangle([int(t0[0]), int(t0[1]), int(t1[0]), int(t1[1])], fill=(190, 185, 175, 255))
    e0, e1 = T(cx - 24, float(top + 90)), T(cx + 24, float(top + 158))
    dr.ellipse([int(e0[0]), int(e0[1]), int(e1[0]), int(e1[1])], fill=(*VIOLET_CRACK, 255))
    a1a, a1b = T(cx - 30, float(top + 98)), T(cx - 105, float(top + 182))
    a2a, a2b = T(cx + 30, float(top + 98)), T(cx + 105, float(top + 182))
    dr.line([a1a, a1b], fill=(200, 195, 185, 255), width=12)
    dr.line([a2a, a2b], fill=(200, 195, 185, 255), width=12)
    return im


def generate_threat_orc() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, int(SPRITE * 0.48)
    mag = 1.32
    pts = _scale_pts(
        cx,
        cy,
        mag,
        [
            (cx - 95, cy + 50),
            (cx - 85, cy - 60),
            (cx - 40, cy - 95),
            (cx + 40, cy - 95),
            (cx + 85, cy - 55),
            (cx + 95, cy + 55),
            (cx, cy + 75),
        ],
    )
    _blob(dr, pts, (70, 95, 78, 255))
    p1, p2 = _scale_pts(cx, cy, mag, [(cx - 80, cy - 40), (cx - 80, cy + 35)])
    dr.line([p1, p2], fill=(*AMBER_GLOW, 255), width=10)
    e0, e1 = _scale_pts(cx, cy, mag, [(cx - 26, cy - 58), (cx + 26, cy - 12)])
    dr.ellipse([int(e0[0]), int(e0[1]), int(e1[0]), int(e1[1])], fill=(55, 70, 58, 255))
    return im


def generate_threat_troll() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, int(SPRITE * 0.5)
    mag = 1.22
    b0, b1 = _scale_pts(cx, cy, mag, [(cx - 118, cy - 108), (cx + 118, cy + 118)])
    dr.ellipse([int(b0[0]), int(b0[1]), int(b1[0]), int(b1[1])], fill=(88, 72, 62, 255))
    for ang in (-0.4, 0.0, 0.35):
        x1 = cx + mag * (90 * math.cos(ang + math.pi / 2))
        y1 = cy + mag * (90 * math.sin(ang + math.pi / 2))
        x2 = cx + mag * (48 * math.cos(ang))
        y2 = cy + mag * (48 * math.sin(ang))
        dr.line([(x1, y1), (x2, y2)], fill=(*GOLD, 220), width=7)
    e0, e1 = _scale_pts(cx, cy, mag, [(cx - 40, cy - 58), (cx + 40, cy - 2)])
    dr.ellipse([int(e0[0]), int(e0[1]), int(e1[0]), int(e1[1])], fill=(50, 42, 38, 255))
    return im


def generate_threat_dragon() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, int(SPRITE * 0.48)
    mag = 1.2
    wing = [
        (cx - 140, cy + 20),
        (cx - 100, cy - 90),
        (cx - 20, cy - 110),
        (cx + 20, cy - 110),
        (cx + 100, cy - 90),
        (cx + 140, cy + 20),
        (cx + 40, cy + 40),
        (cx, cy + 65),
        (cx - 40, cy + 40),
    ]
    _blob(dr, _scale_pts(cx, cy, mag, wing), (35, 28, 55, 255))
    e0, e1 = _scale_pts(cx, cy, mag, [(cx - 42, cy - 98), (cx + 42, cy - 32)])
    dr.ellipse([int(e0[0]), int(e0[1]), int(e1[0]), int(e1[1])], fill=(40, 32, 58, 255))
    h1 = _scale_pts(cx, cy, mag, [(cx - 30, cy - 88), (cx - 58, cy - 138), (cx - 15, cy - 95)])
    h2 = _scale_pts(cx, cy, mag, [(cx + 30, cy - 88), (cx + 58, cy - 138), (cx + 15, cy - 95)])
    dr.polygon([h1[0], h1[1], h1[2]], fill=(55, 45, 75, 255))
    dr.polygon([h2[0], h2[1], h2[2]], fill=(55, 45, 75, 255))
    le0, le1 = _scale_pts(cx, cy, mag, [(cx - 16, cy - 74), (cx - 4, cy - 56)])
    ri0, ri1 = _scale_pts(cx, cy, mag, [(cx + 4, cy - 74), (cx + 16, cy - 56)])
    dr.ellipse([int(le0[0]), int(le0[1]), int(le1[0]), int(le1[1])], fill=(255, 220, 120, 255))
    dr.ellipse([int(ri0[0]), int(ri0[1]), int(ri1[0]), int(ri1[1])], fill=(255, 220, 120, 255))
    return im


def generate_flare_escape() -> Image.Image:
    """Creature-agnostic abstract burst — no faces, claws, or species shapes."""
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx = cy = SPRITE // 2
    for i in range(16):
        ang = (i / 16.0) * 2 * math.pi
        x2 = cx + int(340 * math.cos(ang))
        y2 = cy + int(340 * math.sin(ang))
        dr.line([(cx, cy), (x2, y2)], fill=(*GOLD, int(70 + i * 10)), width=16)
    for r in range(200, 15, -28):
        a = int(min(255, 140 * (1 - r / 200) + 40))
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 248, 220, a))
    dr.ellipse([cx - 42, cy - 42, cx + 42, cy + 42], fill=(255, 255, 255, 255))
    return im.filter(ImageFilter.GaussianBlur(radius=1.0))


def generate_dark_anchor() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    cx, cy = SPRITE // 2, SPRITE // 2
    dr.ellipse([cx - 220, cy - 220, cx + 220, cy + 220], fill=(*VIOLET_CRACK, 55))
    mag = 1.65
    raw = [(cx, cy - 90), (cx + 55, cy - 20), (cx + 35, cy + 75), (cx - 35, cy + 75), (cx - 55, cy - 20)]
    pts = [(int(cx + (x - cx) * mag), int(cy + (y - cy) * mag)) for x, y in raw]
    dr.polygon(pts, fill=(*VIOLET_CRACK, 255))
    dr.line(pts + [pts[0]], fill=(*GOLD, 255), width=8)
    dr.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=(*GOLD, 255))
    return im


def generate_gesture_z_reference() -> Image.Image:
    im = _new_sprite()
    dr = ImageDraw.Draw(im, "RGBA")
    w, h = SPRITE, SPRITE
    dr.line([(w * 0.08, h * 0.22), (w * 0.92, h * 0.22)], fill=(*GOLD, 255), width=16)
    dr.line([(w * 0.92, h * 0.22), (w * 0.10, h * 0.78)], fill=(*GOLD, 255), width=16)
    dr.line([(w * 0.10, h * 0.78), (w * 0.92, h * 0.78)], fill=(*GOLD, 255), width=16)
    return im


def generate_hub_icon() -> Image.Image:
    im = _vertical_gradient((HUB_W, HUB_H), SLATE_TOP, UMBER_MID).convert("RGBA")
    im.putalpha(255)
    dr = ImageDraw.Draw(im, "RGBA")
    sx, sy = int(HUB_W * 0.28), HUB_H // 2
    for k in range(8):
        t = k / 7.0
        r = 40 + t * 70
        a = int(40 + 150 * math.sin(t * math.pi))
        dr.ellipse([sx - r, sy - r, sx + r, sy + r], outline=(*GOLD, a), width=5)
    dr.ellipse([sx - 22, sy - 22, sx + 22, sy + 22], fill=(80, 120, 85, 230))
    # Title strip suggestion (no text — glow only)
    dr.rounded_rectangle(
        [int(HUB_W * 0.48), int(HUB_H * 0.28), int(HUB_W * 0.94), int(HUB_H * 0.72)],
        radius=24,
        fill=(20, 18, 30, 235),
    )
    dr.line([(int(HUB_W * 0.52), int(HUB_H * 0.42)), (int(HUB_W * 0.90), int(HUB_H * 0.42))], fill=(*GOLD, 200), width=5)
    return im


def _ensure_imageset(stem: str) -> Path:
    d = ASSETS / f"{stem}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    contents = d / "Contents.json"
    if not contents.is_file():
        payload = {
            "images": [{"filename": f"{stem}.png", "idiom": "universal", "scale": "1x"}],
            "info": {"author": "xcode", "version": 1},
        }
        contents.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return d


def write_imageset(stem: str, image: Image.Image) -> None:
    d = _ensure_imageset(stem)
    path = d / f"{stem}.png"
    image.save(path, format="PNG", optimize=True)
    print(f"wrote {path.relative_to(REPO)}")


def main() -> None:
    if not ASSETS.is_dir():
        print(f"error: {ASSETS}", file=sys.stderr)
        raise SystemExit(1)

    write_imageset("banishment_ward_bg", generate_ward_bg())
    write_imageset("banishment_tower_bg", generate_tower_bg())
    write_imageset("banishment_ward_ring", generate_ward_ring())
    write_imageset("banishment_threat_goblin", generate_threat_goblin())
    write_imageset("banishment_threat_skeleton", generate_threat_skeleton())
    write_imageset("banishment_threat_orc", generate_threat_orc())
    write_imageset("banishment_threat_troll", generate_threat_troll())
    write_imageset("banishment_threat_dragon", generate_threat_dragon())
    write_imageset("banishment_flare_escape", generate_flare_escape())
    write_imageset("banishment_dark_anchor", generate_dark_anchor())
    write_imageset("banishment_hub_icon", generate_hub_icon())
    write_imageset("banishment_gesture_z_reference", generate_gesture_z_reference())
    print("Done (legacy procedural). Prefer: python3 utility/import_banishment_mockups_to_assets.py")


if __name__ == "__main__":
    main()
