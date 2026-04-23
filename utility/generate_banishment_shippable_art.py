#!/usr/bin/env python3
"""
Deprecated entry point — Banishment catalog art comes from **design mockups**, not procedural drawing.

**Source of truth**
  - PNGs: ``memlog/requirements/Design/MockupScreens/banishment_iphone_*.png``
  - Import: ``python3 utility/import_banishment_mockups_to_assets.py``

**Legacy procedural placeholders** (no mockup fidelity): ``utility/banishment_procedural_placeholder.py``

To force the old generator for emergency local experiments::

    BANISHMENT_USE_PROCEDURAL_ART=1 python3 utility/banishment_procedural_placeholder.py
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
IMPORT_SCRIPT = REPO / "utility" / "import_banishment_mockups_to_assets.py"
LEGACY = REPO / "utility" / "banishment_procedural_placeholder.py"


def main() -> None:
    if os.environ.get("BANISHMENT_USE_PROCEDURAL_ART") == "1":
        print("[banishment] BANISHMENT_USE_PROCEDURAL_ART=1 — running legacy procedural script.", file=sys.stderr)
        raise SystemExit(subprocess.call([sys.executable, str(LEGACY)], cwd=str(REPO)))

    print(
        "generate_banishment_shippable_art.py is deprecated.\n"
        "Run the mockup importer (canonical art):\n"
        f"  python3 {IMPORT_SCRIPT.relative_to(REPO)}\n"
        "Emergency procedural-only placeholders:\n"
        "  BANISHMENT_USE_PROCEDURAL_ART=1 python3 utility/banishment_procedural_placeholder.py",
        file=sys.stderr,
    )
    raise SystemExit(2)


if __name__ == "__main__":
    main()
