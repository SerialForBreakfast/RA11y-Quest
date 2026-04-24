#!/usr/bin/env python3
"""
Remove **edge-connected mid-grey mattes** (common bad export: checkerboard / neutral bed
painted as opaque RGB with alpha=255).

Flood-fills from the image border through pixels that read as flat, desaturated mid-tones
(low chroma, luma in a tunable band). Interior saturated colors (creature paint) are
unchanged unless they connect to the border through a grey path (rare for centered sprites).

Dependencies: Pillow (same as ``transparent_edge_dark_matte.py``).

Example::

    python3 utility/transparent_edge_midgrey_matte.py --in-place \\
        RA11y-iOS/RA11y-iOS/Assets.xcassets/banishment_goblin.imageset/banishment_goblin.png

    python3 utility/transparent_edge_midgrey_matte.py --in-place --all-banishment-encounters
"""

from __future__ import annotations

import argparse
import shutil
import sys
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

sys.path.insert(0, str(Path(__file__).resolve().parent))
from remove_white_background import next_backup_path  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "RA11y-iOS/RA11y-iOS/Assets.xcassets"
BANISHMENT_ENCOUNTER_STEMS = (
    "banishment_goblin",
    "banishment_skeleton",
    "banishment_orc",
    "banishment_troll",
    "banishment_dragon",
)


def _luma(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


def _saturation(r: int, g: int, b: int) -> float:
    mx = max(r, g, b)
    if mx == 0:
        return 0.0
    mn = min(r, g, b)
    return (mx - mn) / mx


def is_midgrey_matte(
    r: int,
    g: int,
    b: int,
    a: int,
    *,
    min_alpha: int,
    max_saturation: float,
    luma_min: float,
    luma_max: float,
) -> bool:
    """True when pixel is likely checkerboard / grey export bed, not subject paint."""
    if a < min_alpha:
        return False
    sat = _saturation(r, g, b)
    if sat > max_saturation:
        return False
    lu = _luma(r, g, b)
    # Mid-grey bed (typical bad export).
    if luma_min <= lu <= luma_max:
        return True
    # Near-black / near-white checker tiles (common in “transparent” previews baked to RGBA).
    if lu < luma_min:
        return lu <= 44.0
    return lu >= 226.0


def remove_edge_connected_midgrey(
    img: Image.Image,
    *,
    min_alpha: int,
    max_saturation: float,
    luma_min: float,
    luma_max: float,
    propagate_interior: bool = True,
    ground_band: float = 0.0,
    ground_luma_dark: float = 14.0,
    ground_luma_bright: float = 248.0,
    ground_chroma_max: int = 14,
) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def matte(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return is_midgrey_matte(
            r,
            g,
            b,
            a,
            min_alpha=min_alpha,
            max_saturation=max_saturation,
            luma_min=luma_min,
            luma_max=luma_max,
        )

    for x in range(w):
        for y in (0, h - 1):
            if not visited[y][x] and matte(x, y):
                visited[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and matte(x, y):
                visited[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and matte(nx, ny):
                visited[ny][nx] = True
                q.append((nx, ny))

    if propagate_interior:
        seed_ground_plane_checker(
            rgba,
            min_alpha=min_alpha,
            band_from_bottom=ground_band,
            luma_dark=ground_luma_dark,
            luma_bright=ground_luma_bright,
            chroma_max=ground_chroma_max,
        )
        propagate_transparency_through_adjacent_matte(
            rgba,
            min_alpha=min_alpha,
            max_saturation=max_saturation,
            luma_min=luma_min,
            luma_max=luma_max,
        )

    return rgba


def seed_ground_plane_checker(
    rgba: Image.Image,
    *,
    min_alpha: int,
    band_from_bottom: float,
    luma_dark: float,
    luma_bright: float,
    chroma_max: int,
) -> None:
    """
    Force **near-monochrome** pixels in the bottom strip of the canvas transparent and
    use them as extra BFS seeds — breaks “caves” of baked checkerboard underfoot that
    never touch the outer transparent ring (opaque rock outlines block matte-only paths).
    """
    if band_from_bottom <= 0:
        return
    w, h = rgba.size
    px = rgba.load()
    y0 = max(0, int(h * (1.0 - band_from_bottom)))
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < min_alpha:
                continue
            if max(r, g, b) - min(r, g, b) > chroma_max:
                continue
            lu = _luma(r, g, b)
            if lu <= luma_dark or lu >= luma_bright:
                px[x, y] = (r, g, b, 0)


def propagate_transparency_through_adjacent_matte(
    rgba: Image.Image,
    *,
    min_alpha: int,
    max_saturation: float,
    luma_min: float,
    luma_max: float,
) -> Image.Image:
    """
    BFS from every **transparent** pixel into **matte-like** opaque neighbors — one pass,
    O(pixels). Removes checkerboard “holes” trapped after the edge flood (e.g. between stones).
    """
    w, h = rgba.size
    px = rgba.load()

    def matte_pixel(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return is_midgrey_matte(
            r,
            g,
            b,
            a,
            min_alpha=min_alpha,
            max_saturation=max_saturation,
            luma_min=luma_min,
            luma_max=luma_max,
        )

    q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < min_alpha:
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if px[nx, ny][3] < min_alpha:
                continue
            if not matte_pixel(nx, ny):
                continue
            r, g, b, _ = px[nx, ny]
            px[nx, ny] = (r, g, b, 0)
            q.append((nx, ny))

    return rgba


def main() -> None:
    p = argparse.ArgumentParser(description="Transparent mid-grey matte connected to PNG edges (checkerboard exports).")
    p.add_argument("files", nargs="*", type=Path, help="PNG paths")
    p.add_argument(
        "--all-banishment-encounters",
        action="store_true",
        help=f"Process {BANISHMENT_ENCOUNTER_STEMS} under Assets.xcassets",
    )
    p.add_argument("--min-alpha", type=int, default=8)
    p.add_argument("--max-saturation", type=float, default=0.22, help="Above this = treated as subject color (0–1)")
    p.add_argument("--luma-min", type=float, default=48.0)
    p.add_argument("--luma-max", type=float, default=188.0)
    p.add_argument(
        "--no-propagate",
        action="store_true",
        help="Skip interior matte propagation (edge flood only).",
    )
    p.add_argument(
        "--ground-band",
        type=float,
        default=0.0,
        help="Bottom fraction (0–1): near B/W low-chroma pixels become transparent seeds before BFS (0=off; try 0.28 for trapped foot checkers).",
    )
    p.add_argument("--ground-luma-dark", type=float, default=14.0)
    p.add_argument("--ground-luma-bright", type=float, default=248.0)
    p.add_argument("--ground-chroma-max", type=int, default=14)
    p.add_argument("--in-place", action="store_true")
    p.add_argument("-o", "--output", type=Path)
    args = p.parse_args()

    if args.in_place and args.output:
        print("error: use either --in-place or -o", file=sys.stderr)
        raise SystemExit(1)

    paths: list[Path] = list(args.files)
    if args.all_banishment_encounters:
        for stem in BANISHMENT_ENCOUNTER_STEMS:
            cand = ASSETS / f"{stem}.imageset" / f"{stem}.png"
            if cand.is_file():
                paths.append(cand)
            else:
                print(f"skip missing {cand.relative_to(REPO)}", file=sys.stderr)

    if not paths:
        print("error: pass PNG paths or --all-banishment-encounters", file=sys.stderr)
        raise SystemExit(1)

    for path in paths:
        path = path.resolve()
        if not path.is_file():
            print(f"skip missing {path}", file=sys.stderr)
            continue
        img = Image.open(path)
        out = remove_edge_connected_midgrey(
            img,
            min_alpha=args.min_alpha,
            max_saturation=args.max_saturation,
            luma_min=args.luma_min,
            luma_max=args.luma_max,
            propagate_interior=not args.no_propagate,
            ground_band=0.0 if args.no_propagate else args.ground_band,
            ground_luma_dark=args.ground_luma_dark,
            ground_luma_bright=args.ground_luma_bright,
            ground_chroma_max=args.ground_chroma_max,
        )
        if args.output:
            out_path = args.output if len(paths) == 1 else args.output / path.name
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out.save(out_path, format="PNG")
            print(f"wrote {out_path}")
        elif args.in_place:
            backup = next_backup_path(path)
            shutil.copy2(path, backup)
            out.save(path, format="PNG")
            print(f"updated {path} backup={backup.name}")
        else:
            print("error: specify --in-place or -o", file=sys.stderr)
            raise SystemExit(1)


if __name__ == "__main__":
    main()
