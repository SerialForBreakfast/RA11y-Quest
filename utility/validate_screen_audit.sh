#!/usr/bin/env bash
# Validates screenshot device folders with ScreenAuditKit (see ScreenAuditKit README).
#
# OCR resolution (first match wins):
#   1) --ocr none|vision
#   2) else if RA11Y_SCREEN_AUDIT_PROFILE=ci then RA11Y_SCREEN_AUDIT_OCR or vision
#   3) else RA11Y_SCREEN_AUDIT_OCR or none
#
# Usage:
#   bash utility/validate_screen_audit.sh
#   bash utility/validate_screen_audit.sh --ocr vision
#   bash utility/validate_screen_audit.sh --ocr none /path/to/screenshots /path/to/output
#
# Migration note:
#   If ScreenAuditKit has been extracted to a standalone repository, set
#   SCREEN_AUDIT_PACKAGE to an empty string and ensure `screenaudit` is on PATH
#   (e.g. via `mint install github.com/[org]/ScreenAuditKit`). The script will
#   automatically prefer the global CLI when SCREEN_AUDIT_PACKAGE is absent or missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREEN_AUDIT_PACKAGE="${SCREEN_AUDIT_PACKAGE:-$ROOT/ScreenAuditKit}"
CONTRACT_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json"
DEFAULT_SCREENSHOT_ROOT="$ROOT/docs/screenshots/en-US"
DEFAULT_OUTPUT_ROOT="$ROOT/build_results/screen-audit"

fail() {
  echo "[screen-audit] ERROR: $*" >&2
  exit 1
}

# Invoke the screenaudit CLI with all arguments forwarded.
# Priority: local package path → global PATH installation.
run_screenaudit() {
  if [[ -d "$SCREEN_AUDIT_PACKAGE" ]]; then
    swift run --package-path "$SCREEN_AUDIT_PACKAGE" screenaudit "$@"
    return
  fi

  if command -v screenaudit &>/dev/null; then
    screenaudit "$@"
    return
  fi

  echo "" >&2
  echo "  ┌──────────────────────────────────────────────────────────────────┐" >&2
  echo "  │  ScreenAuditKit not found.                                       │" >&2
  echo "  │                                                                  │" >&2
  echo "  │  Expected a local package at:                                    │" >&2
  echo "  │    $SCREEN_AUDIT_PACKAGE" >&2
  echo "  │                                                                  │" >&2
  echo "  │  If ScreenAuditKit has been moved to a standalone repository,    │" >&2
  echo "  │  install its CLI globally:                                       │" >&2
  echo "  │    mint install github.com/[org]/ScreenAuditKit                  │" >&2
  echo "  │                                                                  │" >&2
  echo "  │  Or point to a local checkout:                                   │" >&2
  echo "  │    export SCREEN_AUDIT_PACKAGE=/path/to/ScreenAuditKit           │" >&2
  echo "  │                                                                  │" >&2
  echo "  │  See memlog/research/PackageMigration-ScreenAuditKit-NativeUIAuditKit.md" >&2
  echo "  │  for the full migration guide.                                   │" >&2
  echo "  └──────────────────────────────────────────────────────────────────┘" >&2
  echo "" >&2
  exit 2
}

OCR_CLI=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ocr)
      [[ -n "${2:-}" ]] || fail "--ocr requires none or vision"
      OCR_CLI="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,20p' "$0" >&2
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

SCREENSHOT_ROOT="${POSITIONAL[0]:-$DEFAULT_SCREENSHOT_ROOT}"
OUTPUT_ROOT="${POSITIONAL[1]:-$DEFAULT_OUTPUT_ROOT}"

if [[ -n "$OCR_CLI" ]]; then
  SCREEN_AUDIT_OCR="$OCR_CLI"
elif [[ "${RA11Y_SCREEN_AUDIT_PROFILE:-}" == "ci" ]]; then
  SCREEN_AUDIT_OCR="${RA11Y_SCREEN_AUDIT_OCR:-vision}"
else
  SCREEN_AUDIT_OCR="${RA11Y_SCREEN_AUDIT_OCR:-none}"
fi

case "$SCREEN_AUDIT_OCR" in
  none|vision) ;;
  *) fail "Invalid OCR mode: $SCREEN_AUDIT_OCR (use none or vision)" ;;
esac

[[ -f "$CONTRACT_FILE" ]] || fail "Missing ScreenAuditKit contract file: $CONTRACT_FILE"
[[ -d "$SCREENSHOT_ROOT" ]] || fail "Missing screenshot root: $SCREENSHOT_ROOT"

validated=0

for device_dir in "$SCREENSHOT_ROOT"/*; do
  [[ -d "$device_dir" ]] || continue

  device_label="$(basename "$device_dir")"
  output_dir="$OUTPUT_ROOT/$device_label"

  echo "[screen-audit] Validating $device_label (OCR=$SCREEN_AUDIT_OCR)"
  run_screenaudit validate \
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
