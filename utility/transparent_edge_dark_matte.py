#!/usr/bin/env python3
"""
Make near-black matte regions connected to the PNG border transparent (RGBA).

Used when generative art ships with a solid dark backdrop instead of true alpha: flood-fills
from the edges through pixels darker than a threshold so luminous foreground (e.g. a golden
gesture trail) stays opaque. Does **not** modify interior dark pixels disconnected from the frame.

Dependencies: Pillow (same as ``remove_white_background.py``).

Example::

    python3 utility/transparent_edge_dark_matte.py --in-place \\
        RA11y-iOS/RA11y-iOS/Assets.xcassets/banishment_gesture_z_reference.imageset/banishment_gesture_z_reference.png
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


def _luma(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


def remove_edge_connected_dark(
    img: Image.Image,
    *,
    luma_max: float,
    min_alpha: int,
) -> Image.Image:
    """Flood from borders through pixels with luma <= luma_max and alpha >= min_alpha."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def is_matte(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        if a < min_alpha:
            return False
        return _luma(r, g, b) <= luma_max

    for x in range(w):
        for y in (0, h - 1):
            if not visited[y][x] and is_matte(x, y):
                visited[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and is_matte(x, y):
                visited[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_matte(nx, ny):
                visited[ny][nx] = True
                q.append((nx, ny))

    return rgba


def main() -> None:
    parser = argparse.ArgumentParser(description="Transparent dark matte connected to PNG edges.")
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument(
        "--luma-max",
        type=float,
        default=52.0,
        help="Pixels with luma <= this (0–255 scale) are treated as matte (default: 52)",
    )
    parser.add_argument(
        "--min-alpha",
        type=int,
        default=8,
        help="Ignore nearly-transparent pixels when flooding (default: 8)",
    )
    parser.add_argument("--in-place", action="store_true")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()

    if args.in_place and args.output:
        print("error: use either --in-place or -o", file=sys.stderr)
        raise SystemExit(1)

    for path in args.files:
        path = path.resolve()
        if not path.is_file():
            print(f"skip missing {path}", file=sys.stderr)
            continue
        img = Image.open(path)
        out = remove_edge_connected_dark(img, luma_max=args.luma_max, min_alpha=args.min_alpha)
        if args.output:
            out_path = args.output if len(args.files) == 1 else args.output / path.name
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
