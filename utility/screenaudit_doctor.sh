#!/usr/bin/env bash
# Pre-flight checks for RA11y screenshot automation + ScreenAuditKit contracts.
# Does not require PNGs unless --with-audit is used.
#
# Usage:
#   bash utility/screenaudit_doctor.sh
#   bash utility/screenaudit_doctor.sh --with-audit
#   bash utility/screenaudit_doctor.sh --emit-stub
#
# Requires: bash, jq, awk, sed, grep
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json"
CATALOG_FILE="$ROOT/RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md"
UITESTS_DIR="$ROOT/RA11y-iOS/RA11y-iOSUITests"
CONTRACT_CHECK="$ROOT/utility/validate_screenshot_contract.sh"
SCREEN_AUDIT_CHECK="$ROOT/utility/validate_screen_audit.sh"
DEFAULT_SCREENSHOT_ROOT="$ROOT/docs/screenshots/en-US"
DEFAULT_OUTPUT_ROOT="$ROOT/build_results/screen-audit"

WITH_AUDIT=0
EMIT_STUB=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-audit)
      WITH_AUDIT=1
      shift
      ;;
    --emit-stub)
      EMIT_STUB=1
      shift
      ;;
    -h|--help)
      sed -n '1,12p' "$0" >&2
      exit 0
      ;;
    *)
      echo "[screenaudit-doctor] ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "[screenaudit-doctor] ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required (brew install jq)."
command -v awk >/dev/null 2>&1 || fail "awk is required."

[[ -f "$CONTRACT_FILE" ]] || fail "Missing contract: $CONTRACT_FILE"
[[ -f "$CATALOG_FILE" ]] || fail "Missing route catalog: $CATALOG_FILE"

# Basenames from ScreenshotRouteCatalog required table (same rows as validate_screenshot_contract.sh).
catalog_basenames_raw_list() {
  grep '| `testScreenshots_' "$CATALOG_FILE" | sed -n 's/^|[[:space:]]*`\([^`]*\)`.*/\1/p'
}

catalog_basenames_list() {
  catalog_basenames_raw_list | LC_ALL=C sort -u
}

load_catalog_basenames() {
  catalog_basenames=()
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    catalog_basenames+=("$row")
  done < <(catalog_basenames_list)
}

emit_stub_json() {
  load_catalog_basenames
  {
    for cbase in "${catalog_basenames[@]}"; do
      [[ -z "$cbase" ]] && continue
      if jq -e --arg b "$cbase.png" '[.screens[]?.filename] | index($b) != null' "$CONTRACT_FILE" >/dev/null 2>&1; then
        continue
      fi
      scene="$cbase"
      while IFS= read -r line; do
        case "$line" in
          *"\`${cbase}\`"*) ;;
          *) continue ;;
        esac
        extracted="$(echo "$line" | awk -F'`' -v want="$cbase" '$2 == want && NF >= 8 { print $8; exit }')"
        [[ -n "$extracted" ]] && scene="$extracted"
        break
      done < "$CATALOG_FILE"
      jq -n \
        --arg id "$scene" \
        --arg fn "${cbase}.png" \
        '{id:$id, filename:$fn, devices:[], text:{required:[],optional:[],forbidden:[]}, severityOverrides:{}}'
    done
  } | jq -s '.'
}

if [[ "$EMIT_STUB" -eq 1 ]]; then
  emit_stub_json
  exit 0
fi

errors_screenshot_pipeline=()
errors_screen_audit=()

# --- 1) Screenshot automation contract (Fastlane, catalog, scenes, UI tests) ---
set +e
bash "$CONTRACT_CHECK"
code=$?
set -e
if [[ "$code" -ne 0 ]]; then
  errors_screenshot_pipeline+=("validate_screenshot_contract.sh exited $code — fix Fastfile / ScreenshotRouteCatalog / iOSScreenshotScene / RA11y_iOSScreenshots alignment.")
fi

load_catalog_basenames

if [[ "${#catalog_basenames[@]}" -eq 0 ]]; then
  errors_screen_audit+=("No screenshot catalog rows found (expected table rows containing testScreenshots_).")
fi

# Duplicate catalog rows usually mean a copied route row was not fully updated.
while IFS= read -r duplicate_base; do
  [[ -z "$duplicate_base" ]] && continue
  errors_screen_audit+=("ScreenshotRouteCatalog lists duplicate file basename: \`$duplicate_base\`.")
done < <(catalog_basenames_raw_list | LC_ALL=C sort | uniq -d)

# Duplicate contract IDs or filenames make report output ambiguous.
while IFS= read -r duplicate_id; do
  [[ -z "$duplicate_id" ]] && continue
  errors_screen_audit+=("ScreenAuditContracts.json contains duplicate screens[].id: $duplicate_id")
done < <(jq -r '[.screens[]?.id // empty] | map(select(length > 0)) | group_by(.)[] | select(length > 1) | .[0]' "$CONTRACT_FILE")

while IFS= read -r duplicate_filename; do
  [[ -z "$duplicate_filename" ]] && continue
  errors_screen_audit+=("ScreenAuditContracts.json contains duplicate screens[].filename: $duplicate_filename")
done < <(jq -r '[.screens[]?.filename // empty] | map(select(length > 0)) | group_by(.)[] | select(length > 1) | .[0]' "$CONTRACT_FILE")

# --- 2) Contract screens[].filename must match a catalog file basename + .png ---
while IFS= read -r fn; do
  [[ -z "$fn" ]] && continue
  base="${fn%.png}"
  found=0
  for c in "${catalog_basenames[@]}"; do
    if [[ "$c" == "$base" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    errors_screen_audit+=("Contract screen filename not listed in ScreenshotRouteCatalog required table: $fn")
  fi
done < <(jq -r '.screens[]?.filename // empty' "$CONTRACT_FILE")

# --- 3) Every catalog basename should appear in contract ---
for cbase in "${catalog_basenames[@]}"; do
  [[ -z "$cbase" ]] && continue
  if ! jq -e --arg b "$cbase.png" '[.screens[]?.filename] | index($b) != null' "$CONTRACT_FILE" >/dev/null 2>&1; then
    errors_screen_audit+=("ScreenshotRouteCatalog lists file \`$cbase\` but no contract screen has filename \"${cbase}.png\".")
  fi
done

# --- 4) flows[].steps[].screenID must exist in screens[].id ---
while IFS= read -r sid; do
  [[ -z "$sid" ]] && continue
  if ! jq -e --arg s "$sid" '[.screens[]?.id] | index($s) != null' "$CONTRACT_FILE" >/dev/null 2>&1; then
    errors_screen_audit+=("Flow references unknown screen id: $sid")
  fi
done < <(jq -r '.flows[]?.steps[]?.screenID // empty' "$CONTRACT_FILE")

# --- 5) assetProvenancePath file exists when set ---
prov_path="$(jq -r '.assetProvenancePath // empty' "$CONTRACT_FILE")"
if [[ -n "$prov_path" ]]; then
  prov_full="$UITESTS_DIR/$prov_path"
  [[ -f "$prov_full" ]] || errors_screen_audit+=("assetProvenancePath points to missing file: $prov_path (expected under RA11y-iOSUITests)")
fi

# --- 6) Optional full audit ---
if [[ "$WITH_AUDIT" -eq 1 ]]; then
  has_device_dir=0
  if [[ -d "$DEFAULT_SCREENSHOT_ROOT" ]]; then
    for d in "$DEFAULT_SCREENSHOT_ROOT"/*; do
      if [[ -d "$d" ]]; then
        has_device_dir=1
        break
      fi
    done
  fi
  if [[ "$has_device_dir" -eq 1 ]]; then
    set +e
    bash "$SCREEN_AUDIT_CHECK" --ocr "${RA11Y_SCREEN_AUDIT_OCR:-none}" "$DEFAULT_SCREENSHOT_ROOT" "$DEFAULT_OUTPUT_ROOT"
    acode=$?
    set -e
    if [[ "$acode" -ne 0 ]]; then
      errors_screen_audit+=("validate_screen_audit.sh exited $acode — see build_results/screen-audit/<device>/summary.md")
    fi
  else
    errors_screen_audit+=("--with-audit skipped: no device folders under $DEFAULT_SCREENSHOT_ROOT")
  fi
fi

# --- Report ---
if [[ "${#errors_screenshot_pipeline[@]}" -eq 0 && "${#errors_screen_audit[@]}" -eq 0 ]]; then
  echo "[screenaudit-doctor] OK: screenshot pipeline contract + screen audit contract checks passed."
  exit 0
fi

echo "[screenaudit-doctor] Validation failed:" >&2
i=0
if [[ "${#errors_screenshot_pipeline[@]}" -gt 0 ]]; then
  echo "" >&2
  echo "  Screenshot automation (Fastlane / catalog / scenes / UI tests):" >&2
  for e in "${errors_screenshot_pipeline[@]}"; do
    i=$((i + 1))
    echo "    $i) $e" >&2
  done
fi
if [[ "${#errors_screen_audit[@]}" -gt 0 ]]; then
  echo "" >&2
  echo "  Screen audit contract / catalog alignment:" >&2
  for e in "${errors_screen_audit[@]}"; do
    i=$((i + 1))
    echo "    $i) $e" >&2
  done
fi
echo "" >&2
exit 1
