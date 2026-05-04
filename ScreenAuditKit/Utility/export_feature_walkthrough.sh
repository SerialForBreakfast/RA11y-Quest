#!/usr/bin/env bash
# Curates feature-walkthrough PNGs and reports into Docs/FeatureWalkthrough.
# Run from any directory; resolves the ScreenAuditKit package root from this script location.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PACKAGE_ROOT"
swift run screenaudit export-feature-walkthrough --package-root "$PACKAGE_ROOT"
