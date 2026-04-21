#!/usr/bin/env python3
"""
Automated QA for Crystal Resonance PNGs in Assets.xcassets.

**What this catches (common failures):**
  - Missing imageset or PNG
  - Lane / hub sprites saved as **RGB** instead of **RGBA** (grey mats, checkerboard fringes in SwiftUI)
  - Accidentally empty or nearly empty RGBA assets
  - Odd color modes (P, LA, …) that Xcode may mishandle

**What this does *not* replace:**
  - On-device VoiceOver / scroll proxy checks → see memlog QC doc §1, §4
  - Subjective art review → DesignProcess Phase 5 checklist
  - Fixing files → ``utility/ensure_png_rgba.py`` and ``utility/remove_white_background.py``

Usage (repo root)::

    python3 utility/qa_crystal_resonance_png_assets.py
    python3 utility/qa_crystal_resonance_png_assets.py --strict-warnings

**Generative art:** prompt text for diffusion / LLM **image** tools is maintained in
``memlog/requirements/Design/CrystalResonance-ImageGen-PromptTemplate.txt``.
``--llm-snippet`` prints that file to stdout (convenience only).

Exit codes: 0 = no FAIL; 1 = one or more FAIL (or WARN with ``--strict-warnings``).

Requires Pillow (``pip install pillow``), same as other utility scripts.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    print("error: install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from exc

ASSETS_DEFAULT = Path("RA11y-iOS/RA11y-iOS/Assets.xcassets")
IMAGEGEN_PROMPT_TEMPLATE = (
    Path(__file__).resolve().parent.parent
    / "memlog/requirements/Design/CrystalResonance-ImageGen-PromptTemplate.txt"
)


class Severity(str, Enum):
    OK = "OK"
    WARN = "WARN"
    FAIL = "FAIL"


@dataclass
class Finding:
    severity: Severity
    message: str


@dataclass
class AssetReport:
    stem: str
    role: str
    png_path: Path | None
    findings: list[Finding] = field(default_factory=list)

    @property
    def worst(self) -> Severity:
        if any(f.severity == Severity.FAIL for f in self.findings):
            return Severity.FAIL
        if any(f.severity == Severity.WARN for f in self.findings):
            return Severity.WARN
        return Severity.OK


# Keys must match ``iOSDungeonResonanceArt`` and related catalog names.
# role: "background" = full-bleed, RGB preferred; "sprite" = must be RGBA for compositing.
CRYSTAL_RESONANCE_ASSETS: dict[str, str] = {
    "dungeon_resonance_bg": "background",
    "dungeon_resonance_orb_idle": "sprite",
    "dungeon_resonance_orb_locked": "sprite",
    "dungeon_reticle_ring": "sprite",
    "dungeon_target_moonstone": "sprite",
    "dungeon_decoy_ember_shard": "sprite",
    "dungeon_decoy_shadow_glyph": "sprite",
    "dungeon_decoy_sun_sigil": "sprite",
    "dungeon_lane_marker_neutral": "sprite",
    "dungeon_spotlight_mask_reference": "sprite",
    "dungeon_success_flare": "sprite",
}


def find_png_in_imageset(assets_root: Path, imageset_stem: str) -> Path | None:
    imageset_dir = assets_root / f"{imageset_stem}.imageset"
    if not imageset_dir.is_dir():
        return None
    pngs = sorted(imageset_dir.glob("*.png"))
    if not pngs:
        return None
    return pngs[0]


def analyze_png(path: Path, *, role: str) -> list[Finding]:
    findings: list[Finding] = []
    try:
        im = Image.open(path)
    except OSError as e:
        return [Finding(Severity.FAIL, f"unreadable: {e}")]

    mode = im.mode
    w, h = im.size

    if w < 32 or h < 32:
        findings.append(Finding(Severity.WARN, f"very small dimensions {w}×{h}px (verify export scale)"))

    if role == "background":
        if mode not in ("RGB", "RGBA"):
            findings.append(Finding(Severity.WARN, f"mode={mode} (backgrounds usually RGB)"))
        if mode == "RGBA" and im.getbands() == ("R", "G", "B", "A"):
            alpha = im.getchannel("A")
            extrema = alpha.getextrema()
            if extrema != (255, 255):
                findings.append(
                    Finding(
                        Severity.WARN,
                        f"RGBA background with non-opaque alpha range {extrema} — full-bleed bg normally fully opaque RGB",
                    )
                )
        return findings

    # sprite
    if mode == "RGB":
        findings.append(
            Finding(
                Severity.FAIL,
                "RGB (no alpha) — lane/orb/reticle sprites need RGBA or iOS often shows grey mats / checkerboard "
                "fringe on dark UI. Re-export with alpha or run utility/ensure_png_rgba.py",
            )
        )
    elif mode != "RGBA":
        findings.append(Finding(Severity.WARN, f"mode={mode} — expected RGBA for sprites; verify in Xcode"))

    if mode == "RGBA":
        rgba = im.convert("RGBA")
        w, h = rgba.size
        # Grid sample — full ``getdata()`` on wide masters (~1M px) is unnecessarily slow.
        target_samples = 55_000
        step = max(1, int(((w * h) / target_samples) ** 0.5))
        pixels = rgba.load()
        transparent = semi = opaqueish = n = 0
        for y in range(0, h, step):
            for x in range(0, w, step):
                _, _, _, a = pixels[x, y]
                n += 1
                if a == 0:
                    transparent += 1
                elif a < 255:
                    semi += 1
                if a >= 128:
                    opaqueish += 1
        if n == 0:
            findings.append(Finding(Severity.FAIL, "empty image"))
        else:
            if transparent / n > 0.97:
                findings.append(Finding(Severity.WARN, f"{transparent/n:.0%} fully transparent — likely empty or wrong crop"))

            if opaqueish > 0 and semi / opaqueish > 0.35:
                findings.append(
                    Finding(
                        Severity.WARN,
                        "high semi-transparent pixel ratio vs opaque — check for grey halos or premultiply issues",
                    )
                )

    # Wide-canvas authoring note (informational)
    if w > h * 1.25:
        findings.append(
            Finding(
                Severity.OK,
                f"wide master {w}×{h} — OK if authored as landscape master; SwiftUI uses center crop "
                f"(see iOSResonanceWideCanvasImage)",
            )
        )

    return findings


def run_qa(assets_root: Path) -> list[AssetReport]:
    reports: list[AssetReport] = []
    for stem, role in sorted(CRYSTAL_RESONANCE_ASSETS.items()):
        png = find_png_in_imageset(assets_root, stem)
        report = AssetReport(stem=stem, role=role, png_path=png)
        if png is None:
            report.findings.append(
                Finding(
                    Severity.FAIL,
                    f"missing imageset or PNG under {assets_root}/{stem}.imageset/",
                )
            )
        else:
            report.findings.extend(analyze_png(png, role=role))
        if not report.findings:
            report.findings.append(Finding(Severity.OK, "checks passed"))
        reports.append(report)
    return reports


def print_reports(reports: list[AssetReport], *, verbose_ok: bool) -> tuple[int, int, int]:
    ok_c = warn_c = fail_c = 0
    for r in reports:
        worst = r.worst
        if worst == Severity.OK:
            ok_c += 1
        elif worst == Severity.WARN:
            warn_c += 1
        else:
            fail_c += 1
        rel = r.png_path.relative_to(Path.cwd()) if r.png_path and r.png_path.is_absolute() else r.png_path
        prefix = f"[{worst.value}] {r.stem} ({r.role})"
        if r.png_path:
            try:
                rel = r.png_path.resolve().relative_to(Path.cwd().resolve())
            except ValueError:
                rel = r.png_path
            print(f"{prefix}\n  file: {rel}")
        else:
            print(f"{prefix}")
        for f in r.findings:
            if f.severity == Severity.OK and not verbose_ok:
                continue
            print(f"  {f.severity.value}: {f.message}")
        print()
    print(f"Summary: {ok_c} OK, {warn_c} WARN, {fail_c} FAIL (assets: {len(reports)})")
    return ok_c, warn_c, fail_c


def print_llm_snippet() -> None:
    """Print the canonical **image generation** prompt template (stdout only)."""
    path = IMAGEGEN_PROMPT_TEMPLATE
    if path.is_file():
        print(path.read_text(encoding="utf-8").rstrip())
        return
    print(f"error: missing prompt template: {path}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="QA Crystal Resonance PNG assets in Assets.xcassets.")
    parser.add_argument(
        "--assets-root",
        type=Path,
        default=ASSETS_DEFAULT,
        help=f"Asset catalog root (default: {ASSETS_DEFAULT})",
    )
    parser.add_argument(
        "--strict-warnings",
        action="store_true",
        help="Exit 1 if any WARN (default: only FAIL fails the run)",
    )
    parser.add_argument(
        "--verbose-ok",
        action="store_true",
        help="Print OK-level informational findings (e.g. wide-master note)",
    )
    parser.add_argument(
        "--llm-snippet",
        action="store_true",
        help="Print CrystalResonance-ImageGen-PromptTemplate.txt (for diffusion/LLM image tools) and exit 0",
    )
    args = parser.parse_args()

    if args.llm_snippet:
        print_llm_snippet()
        raise SystemExit(0)

    root = args.assets_root.resolve()
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        raise SystemExit(1)

    reports = run_qa(root)
    _, warn_c, fail_c = print_reports(reports, verbose_ok=args.verbose_ok)

    if fail_c > 0:
        raise SystemExit(1)
    if args.strict_warnings and warn_c > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
