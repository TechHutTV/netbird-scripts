#!/usr/bin/env bash
# =============================================================================
# Test Runner for NetBird Helper Scripts
# =============================================================================
# Runs all tests in the tests/ directory and reports results
#
# Usage: ./run-tests.sh [options]
#   -v, --verbose    Show verbose output
#   -q, --quiet      Show only pass/fail summary
#   -h, --help       Show this help
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/tests"
MOCKS_DIR="${SCRIPT_DIR}/mocks"

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
RESET="\033[0m"

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Options
VERBOSE=false
QUIET=false

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show verbose output"
    echo "  -q, --quiet      Show only pass/fail summary"
    echo "  -h, --help       Show this help"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${RESET} $1"
    fi
}

log_pass() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[PASS]${RESET} $1"
    fi
}

log_fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
}

log_warn() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${RESET} $1"
    fi
}

run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Running: $test_name"
    fi

    local output
    local exit_code=0

    # Run the test and capture output
    if [[ "$VERBOSE" == "true" ]]; then
        if bash "$test_file"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        if output=$(bash "$test_file" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_pass "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$test_name"
        if [[ "$VERBOSE" != "true" && -n "${output:-}" ]]; then
            echo "  Output: $output"
        fi
    fi
}

main() {
    echo ""
    echo -e "${BLUE}================================${RESET}"
    echo -e "${BLUE}  NetBird Helper Script Tests${RESET}"
    echo -e "${BLUE}================================${RESET}"
    echo ""

    # Check if tests directory exists
    if [[ ! -d "$TESTS_DIR" ]]; then
        log_fail "Tests directory not found: $TESTS_DIR"
        exit 1
    fi

    # Check if mocks directory exists
    if [[ ! -d "$MOCKS_DIR" ]]; then
        log_fail "Mocks directory not found: $MOCKS_DIR"
        exit 1
    fi

    # Export mock paths for tests
    export MOCK_BUILD_FUNC="${MOCKS_DIR}/build.func"
    export MOCK_INSTALL_FUNC="${MOCKS_DIR}/install.func"
    export PROJECT_ROOT="${SCRIPT_DIR}/.."

    # Find and run all test files
    local test_files
    test_files=$(find "$TESTS_DIR" -name "test_*.sh" -type f | sort)

    if [[ -z "$test_files" ]]; then
        log_warn "No test files found in $TESTS_DIR"
        exit 0
    fi

    log_info "Found $(echo "$test_files" | wc -l) test file(s)"
    echo ""

    while IFS= read -r test_file; do
        run_test "$test_file"
    done <<< "$test_files"

    # Summary
    echo ""
    echo -e "${BLUE}================================${RESET}"
    echo -e "${BLUE}  Test Summary${RESET}"
    echo -e "${BLUE}================================${RESET}"
    echo ""
    echo "  Total:  $TESTS_RUN"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${RESET}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${RESET}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main
