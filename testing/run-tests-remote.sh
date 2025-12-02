#!/usr/bin/env bash
# =============================================================================
# Remote Test Runner for NetBird Helper Scripts
# =============================================================================
# Downloads and runs the test suite without requiring git
#
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechHutTV/netbird-scripts/main/testing/run-tests-remote.sh)"
# =============================================================================

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/TechHutTV/netbird-scripts/main"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Downloading test framework..."

# Create directory structure
mkdir -p "$TEMP_DIR/testing/tests" "$TEMP_DIR/testing/mocks"

# Download files
curl -fsSL "$REPO_RAW/testing/run-tests.sh" -o "$TEMP_DIR/testing/run-tests.sh"
curl -fsSL "$REPO_RAW/testing/mocks/build.func" -o "$TEMP_DIR/testing/mocks/build.func"
curl -fsSL "$REPO_RAW/testing/mocks/install.func" -o "$TEMP_DIR/testing/mocks/install.func"
curl -fsSL "$REPO_RAW/testing/tests/test_ct_script.sh" -o "$TEMP_DIR/testing/tests/test_ct_script.sh"
curl -fsSL "$REPO_RAW/testing/tests/test_install_script.sh" -o "$TEMP_DIR/testing/tests/test_install_script.sh"
curl -fsSL "$REPO_RAW/testing/tests/test_json_config.sh" -o "$TEMP_DIR/testing/tests/test_json_config.sh"

chmod +x "$TEMP_DIR/testing/run-tests.sh"

# Run tests
cd "$TEMP_DIR"
./testing/run-tests.sh "$@"
