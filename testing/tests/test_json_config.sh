#!/usr/bin/env bash
# =============================================================================
# Tests for helper-scripts/json/netbird.json
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

assert_not_empty() {
    local value="$1"
    local message="${2:-Value is empty}"

    if [[ -n "$value" ]]; then
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "FAILED: $message"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# =============================================================================
# Test Cases
# =============================================================================

test_json_file_exists() {
    echo "Testing: JSON config file exists"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ -f "$json_file" ]]; then
        PASSED=$((PASSED + 1))
    else
        echo "FAILED: JSON file not found at $json_file"
        FAILED=$((FAILED + 1))
    fi
}

test_json_is_valid() {
    echo "Testing: JSON is valid syntax"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ ! -f "$json_file" ]]; then
        echo "SKIPPED: JSON file not found"
        return
    fi

    # Try to parse with python (more reliable than jq which may not be installed)
    if command -v python3 &>/dev/null; then
        if python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: JSON is not valid"
            FAILED=$((FAILED + 1))
        fi
    elif command -v jq &>/dev/null; then
        if jq . "$json_file" >/dev/null 2>&1; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: JSON is not valid"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "SKIPPED: No JSON parser available (python3 or jq)"
    fi
}

test_json_has_required_fields() {
    echo "Testing: JSON has required fields"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ ! -f "$json_file" ]]; then
        echo "SKIPPED: JSON file not found"
        return
    fi

    local content
    content=$(cat "$json_file")

    # Required fields for community-scripts format
    local required_fields=(
        '"name":'
        '"slug":'
        '"categories":'
        '"type":'
        '"documentation":'
        '"website":'
        '"description":'
        '"install_methods":'
    )

    for field in "${required_fields[@]}"; do
        if [[ "$content" == *"$field"* ]]; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: Missing required field: $field"
            FAILED=$((FAILED + 1))
        fi
    done
}

test_json_name_matches_app() {
    echo "Testing: JSON name matches APP variable in ct script"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"
    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$json_file" ]] || [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: Required files not found"
        return
    fi

    # Extract name from JSON
    local json_name=""
    if command -v python3 &>/dev/null; then
        json_name=$(python3 -c "import json; print(json.load(open('$json_file'))['name'])" 2>/dev/null)
    fi

    # Extract APP from ct script
    local app_name=""
    app_name=$(grep -E '^APP=' "$ct_script" | head -1 | cut -d'"' -f2)

    if [[ -n "$json_name" ]] && [[ -n "$app_name" ]]; then
        assert_equals "$json_name" "$app_name" "JSON name should match APP in ct script"
    else
        echo "SKIPPED: Could not extract names for comparison"
    fi
}

test_json_resources_match_ct_script() {
    echo "Testing: JSON resources match ct script defaults"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"
    local ct_script="${PROJECT_ROOT}/helper-scripts/ct/netbird.sh"

    if [[ ! -f "$json_file" ]] || [[ ! -f "$ct_script" ]]; then
        echo "SKIPPED: Required files not found"
        return
    fi

    # Extract values from ct script
    local ct_cpu ct_ram ct_disk
    ct_cpu=$(grep -E '^var_cpu=' "$ct_script" | head -1 | cut -d'"' -f2)
    ct_ram=$(grep -E '^var_ram=' "$ct_script" | head -1 | cut -d'"' -f2)
    ct_disk=$(grep -E '^var_disk=' "$ct_script" | head -1 | cut -d'"' -f2)

    if command -v python3 &>/dev/null; then
        local json_cpu json_ram json_disk
        json_cpu=$(python3 -c "import json; print(json.load(open('$json_file'))['install_methods'][0]['resources']['cpu'])" 2>/dev/null)
        json_ram=$(python3 -c "import json; print(json.load(open('$json_file'))['install_methods'][0]['resources']['ram'])" 2>/dev/null)
        json_disk=$(python3 -c "import json; print(json.load(open('$json_file'))['install_methods'][0]['resources']['hdd'])" 2>/dev/null)

        assert_equals "$ct_cpu" "$json_cpu" "CPU should match between JSON and ct script"
        assert_equals "$ct_ram" "$json_ram" "RAM should match between JSON and ct script"
        assert_equals "$ct_disk" "$json_disk" "Disk should match between JSON and ct script"
    else
        echo "SKIPPED: python3 not available for JSON parsing"
    fi
}

test_json_slug_format() {
    echo "Testing: JSON slug is lowercase with no spaces"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ ! -f "$json_file" ]]; then
        echo "SKIPPED: JSON file not found"
        return
    fi

    if command -v python3 &>/dev/null; then
        local slug
        slug=$(python3 -c "import json; print(json.load(open('$json_file'))['slug'])" 2>/dev/null)

        # Check slug is lowercase
        if [[ "$slug" == "${slug,,}" ]] && [[ "$slug" != *" "* ]]; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: Slug should be lowercase with no spaces: $slug"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "SKIPPED: python3 not available"
    fi
}

test_json_type_is_ct() {
    echo "Testing: JSON type is 'ct'"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ ! -f "$json_file" ]]; then
        echo "SKIPPED: JSON file not found"
        return
    fi

    if command -v python3 &>/dev/null; then
        local type_val
        type_val=$(python3 -c "import json; print(json.load(open('$json_file'))['type'])" 2>/dev/null)
        assert_equals "ct" "$type_val" "Type should be 'ct' for container"
    else
        echo "SKIPPED: python3 not available"
    fi
}

test_json_documentation_url_valid() {
    echo "Testing: JSON documentation URL format"

    local json_file="${PROJECT_ROOT}/helper-scripts/json/netbird.json"

    if [[ ! -f "$json_file" ]]; then
        echo "SKIPPED: JSON file not found"
        return
    fi

    if command -v python3 &>/dev/null; then
        local doc_url
        doc_url=$(python3 -c "import json; print(json.load(open('$json_file'))['documentation'])" 2>/dev/null)

        if [[ "$doc_url" == https://* ]]; then
            PASSED=$((PASSED + 1))
        else
            echo "FAILED: Documentation URL should start with https://"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "SKIPPED: python3 not available"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Running JSON config tests..."
echo ""

test_json_file_exists
test_json_is_valid
test_json_has_required_fields
test_json_name_matches_app
test_json_resources_match_ct_script
test_json_slug_format
test_json_type_is_ct
test_json_documentation_url_valid

echo ""
echo "JSON config tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
