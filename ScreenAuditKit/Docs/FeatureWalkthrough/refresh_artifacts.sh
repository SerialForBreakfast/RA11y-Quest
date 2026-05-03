#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_ROOT="$PACKAGE_DIR/.build/test-artifacts/feature-walkthrough"
DEST_ROOT="$SCRIPT_DIR/Artifacts"

if [[ ! -d "$SOURCE_ROOT" ]]; then
  cat >&2 <<EOF
Missing walkthrough test artifacts:
  $SOURCE_ROOT

Run this first:
  swift test --package-path ScreenAuditKit
EOF
  exit 1
fi

copy_file() {
  local source="$1"
  local destination="$2"

  if [[ ! -f "$source" ]]; then
    echo "Missing expected artifact: $source" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
}

copy_reports() {
  local source_scenario="$1"
  local destination_scenario="$2"

  copy_file "$SOURCE_ROOT/$source_scenario/reports/summary.md" "$DEST_ROOT/$destination_scenario/summary.md"
  copy_file "$SOURCE_ROOT/$source_scenario/reports/findings.json" "$DEST_ROOT/$destination_scenario/findings.json"
  copy_file "$SOURCE_ROOT/$source_scenario/reports/evidence.json" "$DEST_ROOT/$destination_scenario/evidence.json"

  if [[ -f "$SOURCE_ROOT/$source_scenario/reports/flow-summary.md" ]]; then
    copy_file "$SOURCE_ROOT/$source_scenario/reports/flow-summary.md" "$DEST_ROOT/$destination_scenario/flow-summary.md"
  fi

  if [[ -d "$SOURCE_ROOT/$source_scenario/reports/overlays" ]]; then
    mkdir -p "$DEST_ROOT/$destination_scenario/overlays"
    find "$SOURCE_ROOT/$source_scenario/reports/overlays" -maxdepth 1 -type f -print | while IFS= read -r overlay; do
      cp "$overlay" "$DEST_ROOT/$destination_scenario/overlays/$(basename "$overlay")"
    done
  fi
}

sanitize_report_paths() {
  local escaped_source_root
  escaped_source_root="${SOURCE_ROOT//\//\\\/}"

  find "$DEST_ROOT" \( -name "*.json" -o -name "*.md" \) -type f -print | while IFS= read -r report; do
    sed -i '' \
      -e "s|$SOURCE_ROOT|<feature-walkthrough-test-output>|g" \
      -e "s|$escaped_source_root|<feature-walkthrough-test-output>|g" \
      "$report"
  done
}

rm -rf "$DEST_ROOT"
mkdir -p "$DEST_ROOT"

copy_file "$SOURCE_ROOT/ios-alert-pass/screenshots/screen.png" "$DEST_ROOT/ios-alert/pass.png"
copy_file "$SOURCE_ROOT/ios-alert-fail/screenshots/screen.png" "$DEST_ROOT/ios-alert/fail.png"
copy_reports "ios-alert-fail" "ios-alert"

copy_file "$SOURCE_ROOT/settings-debug-pass/screenshots/screen.png" "$DEST_ROOT/settings-debug/pass.png"
copy_file "$SOURCE_ROOT/settings-debug-fail/screenshots/screen.png" "$DEST_ROOT/settings-debug/fail.png"
copy_reports "settings-debug-fail" "settings-debug"

copy_file "$SOURCE_ROOT/no-ocr-skip/screenshots/screen.png" "$DEST_ROOT/no-ocr/fixture.png"
copy_reports "no-ocr-skip" "no-ocr"

copy_file "$SOURCE_ROOT/baseline-volatile-pass/baselines/screen.png" "$DEST_ROOT/baseline-drift/baseline.png"
copy_file "$SOURCE_ROOT/baseline-volatile-pass/screenshots/screen.png" "$DEST_ROOT/baseline-drift/ignored-volatile-pass.png"
copy_file "$SOURCE_ROOT/baseline-clipped-fail/screenshots/screen.png" "$DEST_ROOT/baseline-drift/clipped-copy-fail.png"
copy_file "$SOURCE_ROOT/baseline-protected-drift/screenshots/screen.png" "$DEST_ROOT/baseline-drift/stable-cta-fail.png"
copy_reports "baseline-clipped-fail" "baseline-drift"

copy_file "$SOURCE_ROOT/device-orientation-pass/screenshots/screen.png" "$DEST_ROOT/device-orientation/pass.png"
copy_file "$SOURCE_ROOT/device-orientation-fail/screenshots/screen.png" "$DEST_ROOT/device-orientation/fail.png"
copy_reports "device-orientation-fail" "device-orientation"

copy_file "$SOURCE_ROOT/tvos-focus-pass/screenshots/screen.png" "$DEST_ROOT/tvos-focus/pass.png"
copy_file "$SOURCE_ROOT/tvos-focus-fail/screenshots/screen.png" "$DEST_ROOT/tvos-focus/fail.png"
copy_reports "tvos-focus-fail" "tvos-focus"

copy_file "$SOURCE_ROOT/mac-toolbar-pass/screenshots/screen.png" "$DEST_ROOT/mac-toolbar/pass.png"
copy_file "$SOURCE_ROOT/mac-toolbar-fail/screenshots/screen.png" "$DEST_ROOT/mac-toolbar/fail.png"
copy_reports "mac-toolbar-fail" "mac-toolbar"

copy_file "$SOURCE_ROOT/visual-artifacts-pass/screenshots/art.png" "$DEST_ROOT/visual-artifacts/pass-art.png"
copy_file "$SOURCE_ROOT/visual-artifacts-fail/screenshots/matte.png" "$DEST_ROOT/visual-artifacts/fail-flat-matte.png"
copy_file "$SOURCE_ROOT/visual-artifacts-fail/screenshots/checker.png" "$DEST_ROOT/visual-artifacts/fail-checkerboard.png"
copy_file "$SOURCE_ROOT/visual-artifacts-fail/screenshots/alpha.png" "$DEST_ROOT/visual-artifacts/fail-opaque-alpha-border.png"
copy_reports "visual-artifacts-fail" "visual-artifacts"

copy_file "$SOURCE_ROOT/flow-completeness-pass/screenshots/01_Welcome.png" "$DEST_ROOT/flow-completeness/pass-01-welcome.png"
copy_file "$SOURCE_ROOT/flow-completeness-pass/screenshots/02_Permissions.png" "$DEST_ROOT/flow-completeness/pass-02-permissions.png"
copy_file "$SOURCE_ROOT/flow-completeness-pass/screenshots/03_Ready.png" "$DEST_ROOT/flow-completeness/pass-03-ready.png"
copy_file "$SOURCE_ROOT/flow-completeness-fail/screenshots/01_Welcome.png" "$DEST_ROOT/flow-completeness/fail-01-welcome.png"
copy_file "$SOURCE_ROOT/flow-completeness-fail/screenshots/03_Ready.png" "$DEST_ROOT/flow-completeness/fail-03-ready.png"
copy_reports "flow-completeness-fail" "flow-completeness"

copy_file "$SOURCE_ROOT/clean-happy-path/screenshots/01_Welcome.png" "$DEST_ROOT/clean-happy-path/01-welcome.png"
copy_file "$SOURCE_ROOT/clean-happy-path/screenshots/02_Permissions.png" "$DEST_ROOT/clean-happy-path/02-permissions.png"
copy_file "$SOURCE_ROOT/clean-happy-path/screenshots/03_Ready.png" "$DEST_ROOT/clean-happy-path/03-ready.png"
copy_reports "clean-happy-path" "clean-happy-path"

sanitize_report_paths

echo "Refreshed walkthrough artifacts in $DEST_ROOT"
