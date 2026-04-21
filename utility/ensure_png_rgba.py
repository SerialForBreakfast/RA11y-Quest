#!/usr/bin/env python3
"""
Ensure PNGs in the iOS asset catalog use RGBA where compositing expects an alpha channel.

- **Backgrounds** (full-bleed scenes): left as **RGB** — no alpha required per design.
- **Sprites / overlays** (orbs, reticle, markers, flares, hub icons, mask reference): run the same
  edge flood-fill as ``remove_white_background.py`` so near-white mats touching the border become
  transparent (imports shared helpers).
- **Scene cards** (e.g. ``dungeon_room_*``): **RGB → RGBA** with alpha=255 everywhere — no flood-fill,
  so illustrated interiors are not damaged; fixes “grey matte” class issues in some pipelines by
  using a consistent color type.

Usage (from repo root)::

    python3 utility/ensure_png_rgba.py --dry-run
    python3 utility/ensure_png_rgba.py

Requires Pillow (same as ``remove_white_background.py``).
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

# Reuse edge logic from sibling module (same directory).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from remove_white_background import (  # noqa: E402
    next_backup_path,
    remove_edge_connected_near_white,
    warn_if_screenshot_like,
)

ASSETS_DEFAULT = Path("RA11y-iOS/RA11y-iOS/Assets.xcassets")

# Basenames (no path) that must stay **RGB** — full-bleed backgrounds only.
OPAQUE_BACKGROUND_STEMS: frozenset[str] = frozenset(
    {
        "dungeon_descent_bg",
        "dungeon_resonance_bg",
        "enchanter_tower_shelf_bg",
        "hub_quest_board_bg",
        "rogue_trap_door_bg",
        "simon_room_bg",
    }
)

# Imagesets whose PNGs should get **edge** transparency (not just RGBA re-encode).
EDGE_SPRITE_IMAGESET_PREFIXES: tuple[str, ...] = (
    "dungeon_lane_marker_neutral",
    "dungeon_resonance_orb_",
    "dungeon_reticle_ring",
    "dungeon_target_",
    "dungeon_decoy_",
    "dungeon_success_flare",
    "dungeon_spotlight_mask_reference",
    "dungeon_hub_icon",
    "enchanter_hub_icon",
    "rogue_hub_icon",
)

# ``dungeon_room_*`` and any future “card” art: RGBA opaque only.
ROOM_SCENE_PREFIX = "dungeon_room_"


def is_opaque_background(path: Path) -> bool:
    stem = path.stem
    return stem in OPAQUE_BACKGROUND_STEMS


def wants_edge_sprite(path: Path) -> bool:
    parent = path.parent.name
    if not parent.endswith(".imageset"):
        return False
    base = parent[: -len(".imageset")]
    for prefix in EDGE_SPRITE_IMAGESET_PREFIXES:
        if base == prefix or base.startswith(prefix):
            return True
    return False


def is_room_scene(path: Path) -> bool:
    return path.parent.name.startswith(ROOM_SCENE_PREFIX)


def rgba_opaque_convert(path: Path, *, dry_run: bool) -> str:
    img = Image.open(path)
    warn_if_screenshot_like(img.width, img.height, allow_large=True)
    if img.mode == "RGBA":
        return "skip-already-rgba"
    if dry_run:
        return "would-rgba-opaque"
    backup = next_backup_path(path)
    shutil.copy2(path, backup)
    rgba = img.convert("RGBA")
    rgba.save(path, format="PNG")
    return f"wrote-rgba-opaque backup={backup.name}"


def edge_convert(path: Path, *, fuzz: int, edge_matte: bool, dry_run: bool) -> str:
    img = Image.open(path)
    warn_if_screenshot_like(img.width, img.height, allow_large=True)
    if dry_run:
        return "would-edge"
    backup = next_backup_path(path)
    shutil.copy2(path, backup)
    out = remove_edge_connected_near_white(img, fuzz, edge_matte=edge_matte)
    out.save(path, format="PNG")
    return f"wrote-edge backup={backup.name}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize PNG alpha usage in Assets.xcassets.")
    parser.add_argument(
        "--assets-root",
        type=Path,
        default=ASSETS_DEFAULT,
        help=f"Asset catalog root (default: {ASSETS_DEFAULT})",
    )
    parser.add_argument(
        "--fuzz",
        type=int,
        default=20,
        help="Edge flood fuzz (same as remove_white_background.py)",
    )
    parser.add_argument(
        "--edge-matte",
        action="store_true",
        help="Pass through to edge removal for light grey edge mats (riskier).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned actions only",
    )
    args = parser.parse_args()
    root: Path = args.assets_root.resolve()
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        raise SystemExit(1)

    pngs = sorted(root.rglob("*.png"))
    if not pngs:
        print(f"error: no PNGs under {root}", file=sys.stderr)
        raise SystemExit(1)

    summary: dict[str, int] = {}

    for path in pngs:
        if "AppIcon" in str(path):
            continue
        rel = path.relative_to(root)
        try:
            im = Image.open(path)
        except OSError as e:
            print(f"skip unreadable {rel}: {e}")
            continue

        if is_opaque_background(path):
            if im.mode != "RGB":
                print(f"{rel}\tbackground\tmode={im.mode}\t(leave file; verify art intent)")
            summary["background_checked"] = summary.get("background_checked", 0) + 1
            continue

        action = None
        if wants_edge_sprite(path):
            action = edge_convert(path, fuzz=args.fuzz, edge_matte=args.edge_matte, dry_run=args.dry_run)
        elif is_room_scene(path) and im.mode == "RGB":
            action = rgba_opaque_convert(path, dry_run=args.dry_run)
        elif im.mode == "RGB":
            # Other RGB (unexpected): promote to RGBA opaque for consistent encoding.
            action = rgba_opaque_convert(path, dry_run=args.dry_run)
        elif im.mode != "RGBA":
            if args.dry_run:
                action = f"would-convert-{im.mode}-to-rgba"
            else:
                backup = next_backup_path(path)
                shutil.copy2(path, backup)
                Image.open(path).convert("RGBA").save(path, format="PNG")
                action = f"wrote-{im.mode}-to-rgba backup={backup.name}"

        if action:
            key = action.split()[0] if action else "noop"
            summary[key] = summary.get(key, 0) + 1
            print(f"{rel}\t{action}")

    print("\nSummary:", dict(sorted(summary.items())))


if __name__ == "__main__":
    main()
