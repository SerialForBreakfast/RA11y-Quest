#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREEN_AUDIT_PACKAGE="$ROOT/ScreenAuditKit"
CONTRACT_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json"
DEFAULT_SCREENSHOT_ROOT="$ROOT/docs/screenshots/en-US"
DEFAULT_OUTPUT_ROOT="$ROOT/build_results/screen-audit"

SCREENSHOT_ROOT="${1:-$DEFAULT_SCREENSHOT_ROOT}"
OUTPUT_ROOT="${2:-$DEFAULT_OUTPUT_ROOT}"
# Set RA11Y_SCREEN_AUDIT_OCR=vision to run Vision OCR (slower; enables text rules). Default: none.
SCREEN_AUDIT_OCR="${RA11Y_SCREEN_AUDIT_OCR:-none}"

fail() {
  echo "[screen-audit] ERROR: $*" >&2
  exit 1
}

[[ -d "$SCREEN_AUDIT_PACKAGE" ]] || fail "Missing ScreenAuditKit package: $SCREEN_AUDIT_PACKAGE"
[[ -f "$CONTRACT_FILE" ]] || fail "Missing ScreenAuditKit contract file: $CONTRACT_FILE"
[[ -d "$SCREENSHOT_ROOT" ]] || fail "Missing screenshot root: $SCREENSHOT_ROOT"

validated=0

for device_dir in "$SCREENSHOT_ROOT"/*; do
  [[ -d "$device_dir" ]] || continue

  device_label="$(basename "$device_dir")"
  output_dir="$OUTPUT_ROOT/$device_label"

  echo "[screen-audit] Validating $device_label"
  swift run --package-path "$SCREEN_AUDIT_PACKAGE" screenaudit validate \
    --screenshots "$device_dir" \
    --contracts "$CONTRACT_FILE" \
    --output "$output_dir" \
    --ocr "$SCREEN_AUDIT_OCR"

  validated=$((validated + 1))
done

if [[ "$validated" -eq 0 ]]; then
  fail "No screenshot device directories found under: $SCREENSHOT_ROOT"
fi

echo "[screen-audit] OK: validated $validated screenshot folder(s). Reports: $OUTPUT_ROOT"
