#!/usr/bin/env python3
"""
Remove near-white *background* from PNG icons while preserving white that is part of the glyph.

Strategy (default ``--mode edge``)
==================================
Flood-fill from all border pixels: any pixel that is "near white" and connected (4-way)
to the image edge through near-white pixels is made transparent. White pixels that are
**not** connected to the edge (e.g. highlights inside a symbol) stay opaque.

This matches typical sprite sheets: solid white backdrop touching the edges, artwork in
the middle. It fails when a white region in the artwork connects to the border through
another white path (rare).

Do **not** run edge mode on full-screen **screenshots** or on painted scene art (e.g.
``*_bg.png``, ``dungeon_room_*.png``): only on relic / seal / hub icon sprites that sit
on a flat white field.

**Light grey mattes** (e.g. ``#ececec`` export beds) are **not** removed by default edge
mode. Options: (1) re-export PNG with true alpha from the art tool; (2) try ``--edge-matte``
(flood-fills light neutral greys from the border — **verify** glyphs did not connect to the
edge through grey); (3) ``--mode global`` with a tight ``--fuzz`` only when the glyph uses
no near-white interior (aggressive).

**Dimensions:** MVP game sprites are often landscape RGB (e.g. 1376×768) with no alpha
until processed. The default size guard distinguishes those from device screenshots
(tall portrait or large two-axis tablet frames) so you usually **do not** need
``--allow-large`` for relics and seals.

**Safe batch (preview to ``build_results/nobg_preview`` first):**

    find RA11y-iOS/RA11y-iOS/Assets.xcassets -name '*.png' \\
      \\( -path '*enchanter_relic_*' -o -path '*rogue_seal_*' -o -path '*_hub_icon*' \\) \\
      | xargs python3 utility/remove_white_background.py -o build_results/nobg_preview/

Alternative: ImageMagick (global white removal — aggressive)
============================================================
Removes *all* pixels matching white, including interior highlights::

    magick input.png -fuzz 5%% -transparent white output.png

Use only when the glyph contains no light/white you need to keep.

Dependencies
==============
    pip install pillow

Usage examples
================
Single file to stdout path::

    python3 utility/remove_white_background.py -o build_results/out_preview.png \\
        RA11y-iOS/RA11y-iOS/Assets.xcassets/enchanter_relic_dragon_scale.imageset/enchanter_relic_dragon_scale.png

Batch into a folder (flattened basenames)::

    find RA11y-iOS/RA11y-iOS/Assets.xcassets -name '*.png' -print0 | \\
      xargs -0 python3 utility/remove_white_background.py -o build_results/nobg_preview/

In-place (backs up ``.png.bak``, or ``.png.bak.1``, ``.png.bak.2``, … if a backup
already exists so a second run does not overwrite the first backup)::

    python3 utility/remove_white_background.py --in-place file1.png file2.png
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


def is_near_white(r: int, g: int, b: int, fuzz: int) -> bool:
    """True if RGB is within ``fuzz`` of pure white (channel-wise)."""
    return r >= 255 - fuzz and g >= 255 - fuzz and b >= 255 - fuzz


def is_near_light_neutral_matte(r: int, g: int, b: int, fuzz: int) -> bool:
    """
    True for flat light grey / off-white mats that touch the image edge (common bad exports).

    More aggressive than ``is_near_white`` — use only with ``--edge-matte`` and inspect output:
    silver highlights on glyphs can connect to the border through a grey path and be erased.
    """
    mx = max(r, g, b)
    mn = min(r, g, b)
    if mx < 200 - fuzz:
        return False
    if mx - mn > 28 + fuzz // 2:
        return False
    return mx >= 235 - fuzz


def remove_edge_connected_near_white(img: Image.Image, fuzz: int, *, edge_matte: bool = False) -> Image.Image:
    """
    Sets alpha to 0 for near-white pixels connected to any image edge.

    ``img`` is converted to RGBA. Mutates a copy.
    """
    rgba = img.convert("RGBA")
    out = rgba.copy()
    pixels = out.load()
    w, h = out.size

    q: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    def try_seed(x: int, y: int) -> None:
        if (x, y) in visited:
            return
        r, g, b, a = pixels[x, y]
        if a == 0:
            visited.add((x, y))
            return
        is_bg = is_near_white(r, g, b, fuzz) or (
            edge_matte and is_near_light_neutral_matte(r, g, b, fuzz)
        )
        if is_bg:
            visited.add((x, y))
            q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        if h > 1:
            try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        if w > 1:
            try_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if (nx, ny) in visited:
                continue
            nr, ng, nb, na = pixels[nx, ny]
            if na == 0:
                visited.add((nx, ny))
                continue
            is_nb = is_near_white(nr, ng, nb, fuzz) or (
                edge_matte and is_near_light_neutral_matte(nr, ng, nb, fuzz)
            )
            if is_nb:
                visited.add((nx, ny))
                q.append((nx, ny))

    return out


def remove_global_near_white(img: Image.Image, fuzz: int) -> Image.Image:
    """Every near-white pixel becomes transparent (ImageMagick-style)."""
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if is_near_white(r, g, b, fuzz):
                pixels[x, y] = (r, g, b, 0)
    return rgba


def looks_like_device_screenshot(w: int, h: int) -> bool:
    """
    Heuristic: block typical full-screen simulator captures, allow 1376×768-style sprites.

    - Tall phone portrait (e.g. 1206×2622): max side very large.
    - Large tablet / phone rectangles: both axes substantial (excludes landscape sprites
      where the short side stays ~768).
    """
    short_side = min(w, h)
    long_side = max(w, h)
    if long_side > 2200:
        return True
    if short_side > 900 and long_side > 1100:
        return True
    return False


def warn_if_screenshot_like(w: int, h: int, allow_large: bool) -> None:
    """Abort unless ``--allow-large`` when dimensions resemble a full UI screenshot."""
    if allow_large:
        return
    if looks_like_device_screenshot(w, h):
        print(
            "error: image dimensions look like a full-screen screenshot (not a 1376×768-style sprite). "
            "Pass --allow-large to force, or use --dry-run first.",
            file=sys.stderr,
        )
        raise SystemExit(2)


def next_backup_path(path: Path) -> Path:
    """
    Returns ``name.png.bak`` if free, else ``name.png.bak.1``, ``.bak.2``, …
    so re-running ``--in-place`` does not overwrite an existing backup.
    """
    first = path.with_suffix(path.suffix + ".bak")
    if not first.exists():
        return first
    n = 1
    while True:
        candidate = path.with_suffix(f"{path.suffix}.bak.{n}")
        if not candidate.exists():
            return candidate
        n += 1


def process_file(
    path: Path,
    *,
    fuzz: int,
    mode: str,
    output_path: Path,
    allow_large: bool,
    edge_matte: bool,
) -> None:
    img = Image.open(path)
    warn_if_screenshot_like(img.width, img.height, allow_large)
    if mode == "edge":
        out = remove_edge_connected_near_white(img, fuzz, edge_matte=edge_matte)
    else:
        out = remove_global_near_white(img, fuzz)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(output_path, format="PNG")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove white/near-white background from PNGs (edge flood-fill or global)."
    )
    parser.add_argument(
        "files",
        nargs="+",
        type=Path,
        help="Input PNG files",
    )
    parser.add_argument(
        "--fuzz",
        type=int,
        default=20,
        help="Per-channel distance from 255 to still count as white (default: 20)",
    )
    parser.add_argument(
        "--mode",
        choices=("edge", "global"),
        default="edge",
        help="edge: only white connected to border (safer for glyphs). "
        "global: all near-white transparent (ImageMagick-like).",
    )
    parser.add_argument(
        "--edge-matte",
        action="store_true",
        help="With --mode edge, also flood-fill light neutral greys touching the border (riskier; QC on device).",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file (single input) or output directory (multiple inputs)",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite each input; keeps backup as <name>.png.bak",
    )
    parser.add_argument(
        "--allow-large",
        action="store_true",
        help="Allow dimensions that look like full device screenshots (normally rejected)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned outputs only",
    )
    args = parser.parse_args()
    files = [p.resolve() for p in args.files if p.is_file()]
    if len(files) != len(args.files):
        print("error: some paths were not files", file=sys.stderr)
        raise SystemExit(1)

    if args.in_place and args.output is not None:
        print("error: use either --in-place or -o, not both", file=sys.stderr)
        raise SystemExit(1)

    if args.output is None and not args.in_place:
        print("error: specify -o/--output or --in-place", file=sys.stderr)
        raise SystemExit(1)

    if args.in_place:
        for path in files:
            backup = next_backup_path(path)
            out_path = path
            if args.dry_run:
                print(f"would backup {path} -> {backup}, write {out_path}")
                continue
            shutil.copy2(path, backup)
            process_file(
                path,
                fuzz=args.fuzz,
                mode=args.mode,
                output_path=out_path,
                allow_large=args.allow_large,
                edge_matte=args.edge_matte,
            )
            print(f"updated {path} (backup {backup})")
        return

    assert args.output is not None
    out_arg = args.output.resolve()
    if len(files) == 1:
        target = out_arg
        if out_arg.exists() and out_arg.is_dir():
            target = out_arg / files[0].name
        if args.dry_run:
            print(f"would write {target}")
            return
        process_file(
            files[0],
            fuzz=args.fuzz,
            mode=args.mode,
            output_path=target,
            allow_large=args.allow_large,
            edge_matte=args.edge_matte,
        )
        print(f"wrote {target}")
        return

    if not out_arg.is_dir():
        print("error: multiple inputs require -o to be an existing or creatable directory", file=sys.stderr)
        raise SystemExit(1)
    for path in files:
        target = out_arg / path.name
        if args.dry_run:
            print(f"would write {target}")
            continue
        process_file(
            path,
            fuzz=args.fuzz,
            mode=args.mode,
            output_path=target,
            allow_large=args.allow_large,
            edge_matte=args.edge_matte,
        )
        print(f"wrote {target}")


if __name__ == "__main__":
    main()
