#!/bin/bash

set -u

WORKSPACE="RA11y.xcworkspace"
IOS_SCHEME="RA11y-iOS"
CORE_PACKAGE_PATH="RA11yCore"
SIMULATOR_NAME="iPhone 17"
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
  --sim NAME             iOS Simulator name (default: "$SIMULATOR_NAME")
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
    destination="platform=iOS Simulator,name=$SIMULATOR_NAME"
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
