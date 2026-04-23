#!/usr/bin/env python3
"""
Automated QA for The Banishment PNGs in Assets.xcassets.

Mirrors ``qa_crystal_resonance_png_assets.py`` for RGB vs RGBA and basic sanity.
Prompts and import order: ``memlog/requirements/Design/Banishment-ImageGen-ExecutionPlan.txt``.
Includes ``banishment_hub_icon`` (1376×768 RGBA) per ``DesignTicket-BanishmentPromptSheet.txt``.

Usage (repo root)::

    python3 utility/qa_banishment_png_assets.py
    python3 utility/qa_banishment_png_assets.py --allow-missing
    python3 utility/qa_banishment_png_assets.py --strict-warnings
    python3 utility/qa_banishment_png_assets.py --llm-snippet

``--allow-missing``: WARN instead of FAIL when a **required** imageset is absent
(use while art is still landing). Optional assets never fail on missing.

Requires Pillow (``pip install pillow``).
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
# Must match ``utility/import_banishment_mockups_to_assets.py`` (portrait masters) and the checklist.
BG_MASTER_WH = (2048, 4096)
SPRITE_WH = (1024, 1024)
HUB_WH = (1376, 768)
# Rejects nearly flat backgrounds (tiny compressed PNGs that read as “broken” in-app).
MIN_BG_LUMA_SAMPLE_VARIANCE = 45.0
IMAGEGEN_PROMPT_TEMPLATE = (
    Path(__file__).resolve().parent.parent
    / "memlog/requirements/Design/Banishment-ImageGen-PromptTemplate.txt"
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
    optional: bool
    findings: list[Finding] = field(default_factory=list)

    @property
    def worst(self) -> Severity:
        if any(f.severity == Severity.FAIL for f in self.findings):
            return Severity.FAIL
        if any(f.severity == Severity.WARN for f in self.findings):
            return Severity.WARN
        return Severity.OK


# Keys must match ``iOSBanishmentArt`` and DesignTicket-BanishmentPromptSheet.
# role: "background" = opaque; "sprite" = RGBA compositing; "hub" = quest thumbnail (RGBA, 1376×768).
BANISHMENT_REQUIRED: dict[str, str] = {
    "banishment_ward_bg": "background",
    "banishment_tower_bg": "background",
    "banishment_ward_ring": "sprite",
    "banishment_threat_goblin": "sprite",
    "banishment_threat_skeleton": "sprite",
    "banishment_threat_orc": "sprite",
    "banishment_threat_troll": "sprite",
    "banishment_threat_dragon": "sprite",
    "banishment_flare_escape": "sprite",
    "banishment_hub_icon": "hub",
}

BANISHMENT_OPTIONAL: dict[str, str] = {
    "banishment_gesture_z_reference": "sprite",
    "banishment_dark_anchor": "sprite",
}


def background_luminance_sample_variance(im: Image.Image) -> float:
    """Mean squared deviation of grayscale samples — low values mean a flat / failed export."""
    g = im.convert("L")
    w, h = g.size
    step = max(24, min(w, h) // 100)
    px = g.load()
    vals: list[int] = []
    for y in range(step // 2, h, step):
        for x in range(step // 2, w, step):
            vals.append(px[x, y])
    if len(vals) < 16:
        return 0.0
    mean = sum(vals) / len(vals)
    return sum((v - mean) ** 2 for v in vals) / len(vals)


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
        if im.size != BG_MASTER_WH:
            findings.append(
                Finding(
                    Severity.FAIL,
                    f"expected master {BG_MASTER_WH[0]}×{BG_MASTER_WH[1]} "
                    f"(import script / design checklist); got {w}×{h}",
                )
            )
        lvar = background_luminance_sample_variance(im)
        if lvar < MIN_BG_LUMA_SAMPLE_VARIANCE:
            findings.append(
                Finding(
                    Severity.FAIL,
                    f"background too flat for full-bleed use (sample luma variance {lvar:.1f} "
                    f"< {MIN_BG_LUMA_SAMPLE_VARIANCE}) — re-run generator or replace with illustrated master",
                )
            )
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

    if role == "hub":
        if im.size != HUB_WH:
            findings.append(
                Finding(
                    Severity.WARN,
                    f"expected {HUB_WH[0]}×{HUB_WH[1]} per DesignTicket-BanishmentPromptSheet (hub siblings); got {w}×{h}",
                )
            )
        if mode == "RGB":
            findings.append(
                Finding(
                    Severity.FAIL,
                    "RGB (no alpha) — hub thumbnails use RGBA like other quest hub icons",
                )
            )
        elif mode != "RGBA":
            findings.append(Finding(Severity.WARN, f"mode={mode} — expected RGBA for hub icon"))
        else:
            findings.extend(analyze_png(path, role="sprite"))
        return findings

    if mode == "RGB":
        findings.append(
            Finding(
                Severity.FAIL,
                "RGB (no alpha) — sprites need RGBA or iOS often shows grey mats / checkerboard "
                "fringe on dark UI. Re-export with alpha or run utility/ensure_png_rgba.py",
            )
        )
    elif mode != "RGBA":
        findings.append(Finding(Severity.WARN, f"mode={mode} — expected RGBA for sprites; verify in Xcode"))

    # Hub thumbnails run sprite alpha heuristics via recursive call — they are not 1024×1024.
    if role == "sprite" and im.size != SPRITE_WH and im.size != HUB_WH:
        findings.append(
            Finding(
                Severity.WARN,
                f"expected {SPRITE_WH[0]}×{SPRITE_WH[1]} per generator; got {w}×{h}",
            )
        )

    if mode == "RGBA":
        rgba = im.convert("RGBA")
        w, h = rgba.size
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

    if w > h * 1.25:
        findings.append(
            Finding(
                Severity.OK,
                f"wide master {w}×{h} — OK if authored wide; SwiftUI should center-crop if needed",
            )
        )

    return findings


def run_qa(assets_root: Path, *, allow_missing: bool) -> list[AssetReport]:
    reports: list[AssetReport] = []
    combined: list[tuple[str, str, bool]] = [
        *((*item, False) for item in BANISHMENT_REQUIRED.items()),
        *((*item, True) for item in BANISHMENT_OPTIONAL.items()),
    ]
    for stem, role, optional in combined:
        png = find_png_in_imageset(assets_root, stem)
        report = AssetReport(stem=stem, role=role, png_path=png, optional=optional)
        if png is None:
            msg = f"missing imageset or PNG under {assets_root}/{stem}.imageset/"
            if optional:
                report.findings.append(Finding(Severity.OK, f"optional — {msg}"))
            elif allow_missing:
                report.findings.append(Finding(Severity.WARN, msg))
            else:
                report.findings.append(Finding(Severity.FAIL, msg))
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
        opt = "optional" if r.optional else "required"
        prefix = f"[{worst.value}] {r.stem} ({r.role}, {opt})"
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
    path = IMAGEGEN_PROMPT_TEMPLATE
    if path.is_file():
        print(path.read_text(encoding="utf-8").rstrip())
        return
    print(f"error: missing prompt template: {path}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="QA The Banishment PNG assets in Assets.xcassets.")
    parser.add_argument(
        "--assets-root",
        type=Path,
        default=ASSETS_DEFAULT,
        help=f"Asset catalog root (default: {ASSETS_DEFAULT})",
    )
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help="WARN instead of FAIL when a required imageset is absent (partial import / WIP)",
    )
    parser.add_argument(
        "--strict-warnings",
        action="store_true",
        help="Exit 1 if any WARN (default: only FAIL fails the run)",
    )
    parser.add_argument(
        "--verbose-ok",
        action="store_true",
        help="Print OK-level informational findings",
    )
    parser.add_argument(
        "--llm-snippet",
        action="store_true",
        help="Print Banishment-ImageGen-PromptTemplate.txt and exit 0",
    )
    args = parser.parse_args()

    if args.llm_snippet:
        print_llm_snippet()
        raise SystemExit(0)

    root = args.assets_root.resolve()
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        raise SystemExit(1)

    reports = run_qa(root, allow_missing=args.allow_missing)
    _, warn_c, fail_c = print_reports(reports, verbose_ok=args.verbose_ok)

    if fail_c > 0:
        raise SystemExit(1)
    if args.strict_warnings and warn_c > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
