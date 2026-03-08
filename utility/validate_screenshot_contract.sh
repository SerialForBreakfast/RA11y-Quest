#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FASTFILE="$ROOT/fastlane/Fastfile"
UI_TEST_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift"
CATALOG_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md"
SCENE_FILE="$ROOT/RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift"

fail() {
  echo "[screenshot-contract] ERROR: $*" >&2
  exit 1
}

[[ -f "$FASTFILE" ]] || fail "Missing Fastfile: $FASTFILE"
[[ -f "$UI_TEST_FILE" ]] || fail "Missing screenshot test file: $UI_TEST_FILE"
[[ -f "$CATALOG_FILE" ]] || fail "Missing screenshot route catalog: $CATALOG_FILE"
[[ -f "$SCENE_FILE" ]] || fail "Missing screenshot scene contract: $SCENE_FILE"

python3 - "$FASTFILE" "$UI_TEST_FILE" "$CATALOG_FILE" "$SCENE_FILE" <<'PY'
import re
import sys
from pathlib import Path

fastfile = Path(sys.argv[1]).read_text(encoding="utf-8")
ui_file = Path(sys.argv[2]).read_text(encoding="utf-8")
catalog = Path(sys.argv[3]).read_text(encoding="utf-8")
scene_file = Path(sys.argv[4]).read_text(encoding="utf-8")

errors = []

# 1) Extract allowlisted test methods from Fastfile.
method_pattern = re.compile(r'RA11y-iOSUITests/RA11y_iOSScreenshots/(testScreenshots_[A-Za-z0-9_]+)')
allowlisted_methods = sorted(set(method_pattern.findall(fastfile)))
if not allowlisted_methods:
    errors.append("Fastfile has no allowlisted screenshot test methods.")

# 2) Ensure each allowlisted method exists in the UI test file.
for method in allowlisted_methods:
    if f"func {method}()" not in ui_file:
        errors.append(f"Allowlisted method missing in UI test file: {method}")

# 3) Extract scene IDs from the app-side screenshot scene contract.
scene_pattern = re.compile(r'case\s+\w+\s*=\s*"([^"]+)"')
scene_ids = sorted(set(scene_pattern.findall(scene_file)))
if not scene_ids:
    errors.append("Screenshot scene file defines no scene IDs.")

# 4) Parse route catalog rows and validate method references + scene references.
rows = []
for line in catalog.splitlines():
    if line.strip().startswith("|") and "`testScreenshots_" in line and "|" in line:
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 7:
            rows.append(parts)

if not rows:
    errors.append("ScreenshotRouteCatalog.md has no screenshot rows with test methods.")

for parts in rows:
    file_name = parts[1]
    method_cell = parts[2]
    scene_cell = parts[4]
    anchor_cell = parts[5]

    method_match = re.search(r'`(testScreenshots_[A-Za-z0-9_]+)`', method_cell)
    scene_match = re.search(r'`([^`]+)`', scene_cell)
    anchor_match = re.search(r'`([^`]+)`', anchor_cell)

    if not method_match:
        errors.append(f"Catalog row missing method: {file_name}")
        continue

    method = method_match.group(1)
    if method not in allowlisted_methods:
        errors.append(f"Catalog method not in Fastfile allowlist: {method}")

    if not scene_match:
        errors.append(f"Catalog row missing scene ID: {file_name}")
    else:
        scene = scene_match.group(1)
        if scene not in scene_ids:
            errors.append(f"Catalog scene not defined in iOSScreenshotScene.swift: {scene}")

    if anchor_match:
        anchor = anchor_match.group(1)
        if anchor not in ui_file and anchor not in scene_file:
            errors.append(f"Catalog anchor not referenced in tests or scene contract: {anchor}")

# 5) Ensure UI tests use the scene contract launch arg.
if '"-screenshotScene"' not in ui_file:
    errors.append('UI test file must launch scenes via "-screenshotScene".')

# 6) Ensure Fastfile validates extracted screenshots against the catalog.
if "expected_screenshot_files" not in fastfile:
    errors.append("Fastfile must validate extracted screenshots against the catalog.")

if errors:
    print("[screenshot-contract] Validation failed:")
    for err in errors:
        print(f"- {err}")
    sys.exit(1)

print("[screenshot-contract] OK: Fastfile allowlist, screenshot scenes, and route catalog are aligned.")
PY
