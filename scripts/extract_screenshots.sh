#!/usr/bin/env bash
#
# extract_screenshots.sh
#
# Extracts PNG attachments from an Xcode 16+ xcresult bundle using
# `xcrun xcresulttool export attachments`, then renames them to their
# human-readable names by parsing the exported manifest.json.
#
# Xcode 16 changed xcresult storage: screenshots are zstd-compressed blobs
# and can no longer be extracted by fastlane snapshot. This script replaces
# that extraction step.
#
# Usage:
#   ./scripts/extract_screenshots.sh <path/to/test.xcresult> <output-dir>
#
# Requirements: xcrun (Xcode 16+), python3
#
# Exit codes:
#   0 — success
#   1 — xcresult not found, xcresulttool failure, or no screenshots extracted

set -euo pipefail

XCRESULT="${1:?Usage: $0 <path/to/test.xcresult> <output-dir>}"
OUTPUT_DIR="${2:?Usage: $0 <path/to/test.xcresult> <output-dir>}"

TEMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

if [ ! -d "$XCRESULT" ]; then
    echo "[extract_screenshots] ERROR: xcresult not found at '${XCRESULT}'" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "[extract_screenshots] Exporting attachments from: ${XCRESULT}"
xcrun xcresulttool export attachments \
    --path "$XCRESULT" \
    --output-path "$TEMP_DIR"

python3 - "$TEMP_DIR" "$OUTPUT_DIR" <<'PYEOF'
"""
Copies exported PNG attachments from the xcresulttool temp directory to the
output directory, deriving human-readable names from manifest.json where
possible.

Strategy: enumerate actual files on disk first; use the manifest only as a
naming hint. This tolerates manifest key-name changes across Xcode versions
without crashing.
"""
import json
import os
import re
import shutil
import sys

temp_dir   = sys.argv[1]
output_dir = sys.argv[2]

# Pattern: strip trailing `_0_<UUID>` with optional extension preservation.
# e.g. "01_Hub_0_A3F2B1C0-…-1234.png" → "01_Hub.png"
UUID_SUFFIX = re.compile(
    r"_0_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(\.[^.]+)?$"
)

# ── Step 1: enumerate exported files (everything except manifest.json) ───────
exported_files = [
    f for f in os.listdir(temp_dir)
    if f != "manifest.json" and os.path.isfile(os.path.join(temp_dir, f))
]

if not exported_files:
    print("[extract_screenshots] ERROR: No files found in temp dir.", file=sys.stderr)
    print(f"[extract_screenshots] Temp dir contents: {os.listdir(temp_dir)}", file=sys.stderr)
    sys.exit(1)

# ── Step 2: build exported-filename → suggested-name map from manifest ───────
# Walks the manifest structure recursively so it handles any nesting or key
# naming that xcresulttool chooses to use. Common key candidates are tried in
# order; first match wins.
EXP_KEYS = ("exportedFileName", "filename", "file", "name")
SUG_KEYS = ("suggestedHumanReadableName", "suggestedName", "humanReadableName", "displayName")

name_map: dict[str, str] = {}

def _walk(obj: object) -> None:
    if isinstance(obj, dict):
        exp = next((obj[k] for k in EXP_KEYS if obj.get(k)), "")
        sug = next((obj[k] for k in SUG_KEYS if obj.get(k)), "")
        if exp and sug:
            name_map[exp] = sug
        for v in obj.values():
            _walk(v)
    elif isinstance(obj, list):
        for item in obj:
            _walk(item)

manifest_path = os.path.join(temp_dir, "manifest.json")
if os.path.exists(manifest_path):
    try:
        with open(manifest_path, encoding="utf-8") as f:
            _walk(json.load(f))
    except Exception as exc:
        print(f"[extract_screenshots] WARNING: manifest.json parse error: {exc}", file=sys.stderr)
        print("[extract_screenshots] Continuing with original filenames.", file=sys.stderr)
else:
    print("[extract_screenshots] WARNING: No manifest.json found; using original filenames.", file=sys.stderr)

# ── Step 3: copy files with clean names ─────────────────────────────────────
copied = 0
for filename in exported_files:
    suggested  = name_map.get(filename, filename)

    match = UUID_SUFFIX.search(suggested)
    if match:
        ext        = match.group(1) or ""
        clean_name = UUID_SUFFIX.sub(ext, suggested)
    else:
        clean_name = suggested

    src = os.path.join(temp_dir, filename)
    dst = os.path.join(output_dir, clean_name)

    # Deduplicate if a file with this name already exists
    if os.path.exists(dst):
        base, ext_part = os.path.splitext(clean_name)
        counter        = 1
        while os.path.exists(dst):
            dst = os.path.join(output_dir, f"{base}_{counter}{ext_part}")
            counter += 1

    shutil.copy2(src, dst)
    print(f"  Saved: {os.path.basename(dst)}")
    copied += 1

if copied == 0:
    print("[extract_screenshots] ERROR: No screenshots were saved.", file=sys.stderr)
    sys.exit(1)

print(f"[extract_screenshots] Done — {copied} screenshot(s) written to: {output_dir}")
PYEOF
