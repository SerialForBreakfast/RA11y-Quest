#!/bin/bash
#
# build_and_test.sh
#
# Builds and tests RA11yCore (Swift package) and RA11y-iOS (Xcode workspace).
#
# Simulator selection: never hardcodes a destination name. At runtime,
# xcrun simctl is queried for available simulators and the best match from
# the preference hierarchy is resolved to a UDID. Pass --sim <name> to
# express a preference; the script falls back gracefully if unavailable.
#
# See AGENTS.md — "Simulator Detection — Required Pattern" for the rule
# that governs all simulator selection in this repo.

set -u

WORKSPACE="RA11y.xcworkspace"
IOS_SCHEME="RA11y-iOS"
CORE_PACKAGE_PATH="RA11yCore"
# Empty = auto-detect from simctl. Pass --sim <name> to express a preference.
SIMULATOR_NAME=""
CONFIGURATION="Debug"
LOG_ROOT="build_results"
IOS_UNIT_TEST_TARGET="RA11y-iOSTests"
IOS_UI_TEST_TARGET="RA11y-iOSUITests"
DERIVED_DATA_RELATIVE="DerivedData"

SKIP_CORE=false
SKIP_CORE_TESTS=false
SKIP_IOS=false
SKIP_IOS_TESTS=false
CLEAN=false
VERBOSE=false
ONLY_CORE=false
ONLY_IOS=false
LIST_SCHEMES=false
INCLUDE_UI_TESTS=false
FAST_MODE=false
AUTO_SKIP=false
ONLY_TESTING_ARGS=()
SKIP_TESTING_ARGS=()

usage() {
    cat <<USAGE
Usage: utility/build_and_test.sh [options]

Options:
  --sim NAME             iOS Simulator preferred name (auto-detected if omitted)
  --workspace PATH       Workspace path (default: "$WORKSPACE")
  --ios-scheme NAME      iOS scheme name (default: "$IOS_SCHEME")
  --core-path PATH       Swift package path (default: "$CORE_PACKAGE_PATH")
  --config NAME          Build configuration (default: "$CONFIGURATION")
  --include-ui-tests     Include iOS UI tests (default: off)
  --fast                 Use build-for-testing + test-without-building for iOS
  --auto-skip            Skip tests when no relevant changes are detected
  --only-testing VALUE   Pass -only-testing:VALUE to xcodebuild (repeatable)
  --skip-testing VALUE   Pass -skip-testing:VALUE to xcodebuild (repeatable)
  --only-core            Build/test only Core (skips iOS)
  --only-ios             Build/test only iOS (skips Core)
  --skip-core            Skip Core build/test
  --skip-core-tests      Skip Core tests
  --skip-ios             Skip iOS build/test
  --skip-ios-tests       Skip iOS tests
  --clean                Clean before build
  --verbose              Print xcodebuild output to console
  --list-schemes          List schemes in the workspace and exit
  --help                 Show this help
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --sim)
            SIMULATOR_NAME="$2"; shift 2;;
        --workspace)
            WORKSPACE="$2"; shift 2;;
        --ios-scheme)
            IOS_SCHEME="$2"; shift 2;;
        --core-path)
            CORE_PACKAGE_PATH="$2"; shift 2;;
        --config)
            CONFIGURATION="$2"; shift 2;;
        --include-ui-tests)
            INCLUDE_UI_TESTS=true; shift;;
        --fast)
            FAST_MODE=true; shift;;
        --auto-skip)
            AUTO_SKIP=true; shift;;
        --only-testing)
            ONLY_TESTING_ARGS+=( -only-testing:"$2" ); shift 2;;
        --skip-testing)
            SKIP_TESTING_ARGS+=( -skip-testing:"$2" ); shift 2;;
        --only-core)
            ONLY_CORE=true; shift;;
        --only-ios)
            ONLY_IOS=true; shift;;
        --skip-core)
            SKIP_CORE=true; shift;;
        --skip-core-tests)
            SKIP_CORE_TESTS=true; shift;;
        --skip-ios)
            SKIP_IOS=true; shift;;
        --skip-ios-tests)
            SKIP_IOS_TESTS=true; shift;;
        --clean)
            CLEAN=true; shift;;
        --verbose)
            VERBOSE=true; shift;;
        --list-schemes)
            LIST_SCHEMES=true; shift;;
        --help)
            usage; exit 0;;
        *)
            echo "Unknown option: $1"; echo ""; usage; exit 1;;
    esac
 done

mkdir -p "$LOG_ROOT"
RUN_ID=$(date +"%Y-%m-%d_%H-%M-%S")
RUN_DIR="$LOG_ROOT/$RUN_ID"
mkdir -p "$RUN_DIR"

SUMMARY_FILE="$RUN_DIR/summary.md"
CORE_BUILD_LOG="$RUN_DIR/core_build.log"
CORE_TEST_LOG="$RUN_DIR/core_test.log"
IOS_BUILD_LOG="$RUN_DIR/ios_build.log"
IOS_TEST_LOG="$RUN_DIR/ios_test.log"
IOS_BUILD_FOR_TESTING_LOG="$RUN_DIR/ios_build_for_testing.log"
IOS_BUILD_RESULT="$RUN_DIR/ios_build.xcresult"
IOS_TEST_RESULT="$RUN_DIR/ios_test.xcresult"
DERIVED_DATA_PATH="$RUN_DIR/$DERIVED_DATA_RELATIVE"

# ---------------------------------------------------------------------------
# resolve_simulator_udid <preferred_name> <family>
#
# Resolves an available iOS simulator UDID via xcrun simctl at runtime.
# Never relies on a hardcoded name as the sole destination selector.
#
# Args:
#   preferred_name  Exact device name to try first. Pass "" to skip.
#   family          "iPhone" or "iPad"
#
# Prints the UDID to stdout. Prints diagnostics to stderr.
# Exits 1 if no simulator of the requested family is available.
#
# Concurrency: pure read-only query; no simulator state is modified.
# ---------------------------------------------------------------------------
resolve_simulator_udid() {
    local preferred_name="$1"
    local family="$2"

    local json
    json=$(xcrun simctl list devices available --json 2>/dev/null) || {
        echo "[simulator] ERROR: 'xcrun simctl list devices available' failed." >&2
        echo "[simulator] Ensure Xcode is installed and Simulator.app has been" >&2
        echo "[simulator] opened at least once since the last reboot." >&2
        return 1
    }

    python3 - "$preferred_name" "$family" <<PYEOF
import json, sys

preferred = sys.argv[1]
family    = sys.argv[2]

# Preference hierarchy per device family (prefix-matched, newest first).
PREFS = {
    "iPhone": [
        "iPhone 17",
        "iPhone 16 Pro",
        "iPhone 16",
        "iPhone 15 Pro",
        "iPhone 15",
        "iPhone 14 Pro",
        "iPhone 14",
    ],
    "iPad": [
        "iPad Pro (13-inch)",
        "iPad Pro (12.9-inch)",
        "iPad Pro",
        "iPad Air",
        "iPad",
    ],
}

try:
    data = json.loads("""$json""")
except Exception as exc:
    print(f"[simulator] Failed to parse simctl JSON: {exc}", file=sys.stderr)
    sys.exit(1)

available = [
    d
    for _runtime, devices in data.get("devices", {}).items()
    for d in devices
    if d.get("isAvailable") and family in d.get("name", "")
]

if not available:
    all_names = sorted({
        d["name"]
        for devices in data.get("devices", {}).values()
        for d in devices
        if d.get("isAvailable")
    })
    print(f"[simulator] ERROR: No available {family} simulator found.", file=sys.stderr)
    print(f"[simulator] All available simulators: {all_names}", file=sys.stderr)
    print("[simulator] Try opening Simulator.app or Xcode -> Settings -> Platforms.", file=sys.stderr)
    sys.exit(1)

# 1. Exact preferred name match.
if preferred:
    for d in available:
        if d["name"] == preferred:
            print(f"[simulator] Resolved: {d['name']} ({d['udid'][:8]}...)", file=sys.stderr)
            print(d["udid"])
            sys.exit(0)
    print(f"[simulator] WARNING: '{preferred}' not found; falling back to preference list.", file=sys.stderr)

# 2. Preference hierarchy (prefix match, newest name first within each tier).
for pref in PREFS.get(family, []):
    candidates = [d for d in available if d["name"].startswith(pref)]
    if candidates:
        chosen = sorted(candidates, key=lambda d: d["name"], reverse=True)[0]
        print(f"[simulator] Resolved via preference list: {chosen['name']} ({chosen['udid'][:8]}...)", file=sys.stderr)
        print(chosen["udid"])
        sys.exit(0)

# 3. Last-resort: any available simulator in the requested family.
chosen = sorted(available, key=lambda d: d["name"], reverse=True)[0]
print(f"[simulator] WARNING: Using last-resort fallback: {chosen['name']} ({chosen['udid'][:8]}...)", file=sys.stderr)
print(chosen["udid"])
PYEOF
}

log() {
    local msg="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $msg"
}

run_cmd() {
    local log_file="$1"
    shift
    if [ "$VERBOSE" = true ]; then
        "$@" | tee "$log_file"
    else
        "$@" > "$log_file" 2>&1
    fi
}

add_result_row() {
    local target="$1"
    local build_status="$2"
    local test_status="$3"
    local notes="$4"
    echo "| $target | $build_status | $test_status | $notes |" >> "$SUMMARY_FILE"
}

log "Starting build run $RUN_ID"

cat <<SUMMARY > "$SUMMARY_FILE"
# Build and Test Summary

Generated: $(date)

| Target | Build Status | Test Status | Notes |
|--------|-------------|-------------|-------|
SUMMARY

if [ "$LIST_SCHEMES" = true ]; then
    log "Listing schemes for workspace: $WORKSPACE"
    xcodebuild -list -workspace "$WORKSPACE"
    exit 0
fi

if [ "$ONLY_CORE" = true ] && [ "$ONLY_IOS" = true ]; then
    echo "Cannot use --only-core and --only-ios together."
    exit 1
fi

if [ "$ONLY_CORE" = true ]; then
    SKIP_IOS=true
fi
if [ "$ONLY_IOS" = true ]; then
    SKIP_CORE=true
fi

if [ "$AUTO_SKIP" = true ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! command -v rg >/dev/null 2>&1; then
        log "Auto-skip disabled: rg not found"
    else
        changed_files=$(git diff --name-only HEAD -- . 2>/dev/null; git diff --name-only --cached -- . 2>/dev/null) || true
        if ! echo "$changed_files" | rg -q "^RA11yCore/"; then
            if [ "$SKIP_CORE_TESTS" = false ]; then
                log "Auto-skip: no RA11yCore changes detected; skipping Core tests"
                SKIP_CORE_TESTS=true
            fi
        fi
        if ! echo "$changed_files" | rg -q "^RA11y-iOS/" && ! echo "$changed_files" | rg -q "^RA11yCore/"; then
            if [ "$SKIP_IOS_TESTS" = false ]; then
                log "Auto-skip: no RA11y-iOS or RA11yCore changes detected; skipping iOS tests"
                SKIP_IOS_TESTS=true
            fi
        fi
    fi
fi

if [ "$CLEAN" = true ]; then
    log "Cleaning derived data and SwiftPM build artifacts"
    rm -rf "$RUN_DIR/DerivedData"
    (cd "$CORE_PACKAGE_PATH" && swift package clean) > "$RUN_DIR/core_clean.log" 2>&1 || true
fi

if [ "$SKIP_CORE" = true ]; then
    add_result_row "RA11yCore" "⚠️ Skipped" "⚠️ Skipped" "Skipped by flag"
else
    log "Building RA11yCore"
    if run_cmd "$CORE_BUILD_LOG" swift build --package-path "$CORE_PACKAGE_PATH"; then
        core_build_status="✅ Success"
    else
        core_build_status="❌ Failure"
    fi

    if [ "$core_build_status" = "✅ Success" ] && [ "$SKIP_CORE_TESTS" = false ]; then
        log "Testing RA11yCore"
        if run_cmd "$CORE_TEST_LOG" swift test --package-path "$CORE_PACKAGE_PATH"; then
            core_test_status="✅ Success"
        else
            core_test_status="❌ Failure"
        fi
    elif [ "$SKIP_CORE_TESTS" = true ]; then
        core_test_status="⚠️ Skipped"
    else
        core_test_status="⚠️ Skipped"
    fi

    add_result_row "RA11yCore" "$core_build_status" "$core_test_status" "See logs in $RUN_DIR"

    if [ "$core_build_status" = "❌ Failure" ]; then
        log "Core build failed; skipping iOS build/test"
        add_result_row "RA11y-iOS" "⚠️ Skipped" "⚠️ Skipped" "Skipped due to Core failure"
        log "Summary: $SUMMARY_FILE"
        exit 1
    fi
fi

if [ "$SKIP_IOS" = true ]; then
    add_result_row "RA11y-iOS" "⚠️ Skipped" "⚠️ Skipped" "Skipped by flag"
else
    log "Resolving iOS simulator${SIMULATOR_NAME:+ (preferred: $SIMULATOR_NAME)}"
    SIMULATOR_UDID=$(resolve_simulator_udid "$SIMULATOR_NAME" "iPhone") || {
        log "No iOS simulator available. Cannot build or test RA11y-iOS."
        add_result_row "RA11y-iOS" "❌ No Simulator" "❌ No Simulator" \
            "No available iPhone simulator found — open Simulator.app and retry"
        exit 1
    }
    destination="platform=iOS Simulator,id=$SIMULATOR_UDID"
    if [ "$FAST_MODE" = true ] && [ "$SKIP_IOS_TESTS" = false ]; then
        log "Building RA11y-iOS for testing ($destination)"
        if run_cmd "$IOS_BUILD_FOR_TESTING_LOG" xcodebuild \
            -workspace "$WORKSPACE" \
            -scheme "$IOS_SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -resultBundlePath "$IOS_BUILD_RESULT" \
            build-for-testing; then
            ios_build_status="✅ Success"
        else
            ios_build_status="❌ Failure"
        fi
    else
        log "Building RA11y-iOS for simulator ($destination)"
        if run_cmd "$IOS_BUILD_LOG" xcodebuild \
            -workspace "$WORKSPACE" \
            -scheme "$IOS_SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -resultBundlePath "$IOS_BUILD_RESULT" \
            build; then
            ios_build_status="✅ Success"
        else
            ios_build_status="❌ Failure"
        fi
    fi

    if [ "$ios_build_status" = "✅ Success" ] && [ "$SKIP_IOS_TESTS" = false ]; then
        log "Testing RA11y-iOS for simulator ($destination)"
        test_args=()
        if [ "$INCLUDE_UI_TESTS" = false ]; then
            test_args+=( -only-testing:"$IOS_UNIT_TEST_TARGET" )
        fi
        if [ ${#ONLY_TESTING_ARGS[@]} -gt 0 ]; then
            test_args+=( "${ONLY_TESTING_ARGS[@]}" )
        fi
        if [ ${#SKIP_TESTING_ARGS[@]} -gt 0 ]; then
            test_args+=( "${SKIP_TESTING_ARGS[@]}" )
        fi
        if run_cmd "$IOS_TEST_LOG" xcodebuild \
            -workspace "$WORKSPACE" \
            -scheme "$IOS_SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -parallel-testing-enabled YES \
            "${test_args[@]}" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -resultBundlePath "$IOS_TEST_RESULT" \
            $( [ "$FAST_MODE" = true ] && echo "test-without-building" || echo "test" ); then
            ios_test_status="✅ Success"
        else
            ios_test_status="❌ Failure"
        fi
    elif [ "$SKIP_IOS_TESTS" = true ]; then
        ios_test_status="⚠️ Skipped"
    else
        ios_test_status="⚠️ Skipped"
    fi

    add_result_row "RA11y-iOS" "$ios_build_status" "$ios_test_status" "See logs in $RUN_DIR"
fi

cat <<SUMMARY_APPEND >> "$SUMMARY_FILE"

## Failure Summary
Core build log: $CORE_BUILD_LOG
Core test log: $CORE_TEST_LOG
iOS build log: $IOS_BUILD_LOG
iOS test log: $IOS_TEST_LOG
iOS build-for-testing log: $IOS_BUILD_FOR_TESTING_LOG
iOS build xcresult: $IOS_BUILD_RESULT
iOS test xcresult: $IOS_TEST_RESULT
SUMMARY_APPEND

log "Failures (if any):"
grep -n "error:" "$CORE_BUILD_LOG" "$CORE_TEST_LOG" "$IOS_BUILD_LOG" "$IOS_TEST_LOG" 2>/dev/null | head -50 || true

log "Summary: $SUMMARY_FILE"
exit 0
