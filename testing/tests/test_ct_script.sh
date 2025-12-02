#!/usr/bin/env bash
# =============================================================================
# Tests for helper-scripts/ct/netbird.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export test mode and mock paths
export TEST_MODE="true"
export MOCK_BUILD_FUNC="${SCRIPT_DIR}/../mocks/build.func"
export PROJECT_ROOT="${PROJECT_ROOT:-${SCRIPT_DIR}/../..}"

# Source the mock for direct function testing
source "${MOCK_BUILD_FUNC}"

# Test counter
PASSED=0
FAILED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "FAILED: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if [[ "$haystack" == *"$needle"* ]]; then
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "FAILED: $message"
        echo "  Looking for: $needle"
        echo "  In: $haystack"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

assert_function_called() {
    local func_name="$1"
    local message="${2:-Function not called}"

    for call in "${MOCK_CALLS[@]:-}"; do
        if [[ "$call" == *"$func_name"* ]]; then
            PASSED=$((PASSED + 1))
            return 0
        fi
    done

    echo "FAILED: $message - $func_name was not called"
    echo "  Calls made: ${MOCK_CALLS[*]:-none}"
    FAILED=$((FAILED + 1))
    return 1
}

# =============================================================================
# Test Cases
# =============================================================================

test_build_func_msg_functions() {
    echo "Testing: build.func msg_* functions"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    msg_info "Test info"
    assert_function_called "msg_info" "msg_info should work"

    msg_ok "Test ok"
    assert_function_called "msg_ok" "msg_ok should work"

    msg_warn "Test warning"
    assert_function_called "msg_warn" "msg_warn should work"

    msg_error "Test error"
    assert_function_called "msg_error" "msg_error should work"
}

test_header_info() {
    echo "Testing: header_info function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    header_info "NetBird"
    assert_function_called "header_info" "header_info should be called"
}

test_variables_function() {
    echo "Testing: variables function sets expected values"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    APP="NetBird"
    var_tags="network;vpn"
    var_cpu="1"
    var_ram="512"
    var_disk="4"
    var_os="debian"
    var_version="13"
    var_unprivileged="1"

    variables

    assert_function_called "variables" "variables should be called"
    assert_equals "netbird" "$NSAPP" "NSAPP should be lowercase APP"
    assert_equals "1" "$CORE_COUNT" "CORE_COUNT should match var_cpu"
    assert_equals "512" "$RAM_SIZE" "RAM_SIZE should match var_ram"
    assert_equals "4" "$DISK_SIZE" "DISK_SIZE should match var_disk"
}

test_color_function() {
    echo "Testing: color function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    color
    assert_function_called "color" "color should be called"
}

test_catch_errors() {
    echo "Testing: catch_errors function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    catch_errors
    assert_function_called "catch_errors" "catch_errors should be called"
}

test_container_check_functions() {
    echo "Testing: container check functions"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    check_container_storage
    assert_function_called "check_container_storage" "check_container_storage should be called"

    check_container_resources
    assert_function_called "check_container_resources" "check_container_resources should be called"
}

test_build_container() {
    echo "Testing: build_container function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    build_container
    assert_function_called "build_container" "build_container should be called"
}

test_start_function() {
    echo "Testing: start function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    start
    assert_function_called "start" "start should be called"
}

test_description_function() {
    echo "Testing: description function"

    MOCK_CALLS=()
    MOCK_MODE="silent"

    description
    assert_function_called "description" "description should be called"
}

test_ct_script_exists() {
    echo "Testing: ct script file exists"

    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ -f "$ct_script" ]]; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: CT script not found at $ct_script"
        FAILED=$((FAILED + 1))
    fi
}

test_ct_script_has_required_variables() {
    echo "Testing: ct script has required variables"

    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: CT script not found"
        return
    fi

    local content
    content=$(cat "$ct_script")

    # Check for required variable declarations
    local required_vars=("APP=" "var_tags=" "var_cpu=" "var_ram=" "var_disk=" "var_os=" "var_version=")

    for var in "${required_vars[@]}"; do
        if [[ "$content" == *"$var"* ]]; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: Missing required variable: $var"
            FAILED=$((FAILED + 1))
        fi
    done
}

test_ct_script_has_update_function() {
    echo "Testing: ct script has update_script function"

    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: CT script not found"
        return
    fi

    if grep -q "function update_script" "$ct_script"; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: Missing update_script function"
        FAILED=$((FAILED + 1))
    fi
}

test_ct_script_sources_build_func() {
    echo "Testing: ct script sources build.func"

    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: CT script not found"
        return
    fi

    if grep -q "build.func" "$ct_script"; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: Script does not source build.func"
        FAILED=$((FAILED + 1))
    fi
}

test_ct_script_runs_with_mocks() {
    echo "Testing: ct script runs with mocks"

    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: CT script not found"
        return
    fi

    # Run the script with test mode and capture output
    local output
    local exit_code=0
    output=$(TEST_MODE=true MOCK_BUILD_FUNC="${MOCK_BUILD_FUNC}" MOCK_MODE=silent bash "$ct_script" 2>&1) || exit_code=$?

    # Script should complete successfully (exit 0)
    if [[ $exit_code -eq 0 ]]; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: CT script exited with code $exit_code"
        echo "Output: $output"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Verify expected output patterns that indicate the script ran correctly
    if [[ "$output" == *"setup has been successfully initialized"* ]]; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: Expected success message not found in output"
        FAILED=$((FAILED + 1))
    fi

    if [[ "$output" == *"netbird up"* ]]; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: Expected 'netbird up' instruction not found"
        FAILED=$((FAILED + 1))
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Running ct script tests..."
echo ""

test_build_func_msg_functions
test_header_info
test_variables_function
test_color_function
test_catch_errors
test_container_check_functions
test_build_container
test_start_function
test_description_function
test_ct_script_exists
test_ct_script_has_required_variables
test_ct_script_has_update_function
test_ct_script_sources_build_func
test_ct_script_runs_with_mocks

echo ""
echo "CT script tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
