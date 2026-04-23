#!/usr/bin/env bash
# Validates The Banishment imagesets under Assets.xcassets (dimensions, alpha, flatness).
# Keep in sync with memlog/requirements/Design/BanishmentAssetRequirements-Checklist.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "[banishment-assets] Running utility/qa_banishment_png_assets.py ..."
python3 "$ROOT/utility/qa_banishment_png_assets.py" \
  --assets-root "$ROOT/RA11y-iOS/RA11y-iOS/Assets.xcassets" \
  "$@"
echo "[banishment-assets] OK."
