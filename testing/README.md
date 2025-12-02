# Testing Framework for NetBird Helper Scripts

This folder contains a testing framework to validate the NetBird helper scripts without requiring a Proxmox VE environment.

## Quick Start

```bash
# Run all tests
./run-tests.sh

# Run with verbose output
./run-tests.sh -v

# Run with minimal output
./run-tests.sh -q
```

## Structure

```
testing/
├── README.md           # This file
├── run-tests.sh        # Main test runner
├── mocks/              # Mock implementations
│   ├── build.func      # Mocks community-scripts build.func
│   └── install.func    # Mocks FUNCTIONS_FILE_PATH for install scripts
└── tests/              # Test files
    ├── test_ct_script.sh       # Tests for ct/netbird.sh
    ├── test_install_script.sh  # Tests for install/netbird-install.sh
    └── test_json_config.sh     # Tests for json/netbird.json
```

## Mock System

The mocks simulate the functions provided by the [community-scripts](https://github.com/community-scripts/ProxmoxVE) framework:

### build.func (for ct scripts)
- `msg_info`, `msg_ok`, `msg_warn`, `msg_error` - Output messages
- `header_info` - Display ASCII header
- `variables` - Set up default variables
- `color` - Initialize color codes
- `catch_errors` - Set up error handling
- `start`, `build_container`, `description` - Container lifecycle
- `check_container_storage`, `check_container_resources` - Validation

### install.func (for install scripts)
- Same messaging functions
- `verb_ip6`, `setting_up_container`, `network_check`, `update_os`
- `motd_ssh`, `customize`
- Mock implementations of `apt-get`, `curl`, `systemctl`

## Mock Modes

Set `MOCK_MODE` environment variable:
- `test` (default) - Normal test output
- `verbose` - Show all mock function output
- `silent` - Suppress all output

```bash
MOCK_MODE=verbose ./run-tests.sh
```

## Adding New Tests

1. Create a new file in `tests/` with prefix `test_`
2. Source the appropriate mock file
3. Define test functions
4. Exit with 0 for success, non-zero for failure

Example:
```bash
#!/usr/bin/env bash
set -euo pipefail

source "${SCRIPT_DIR}/../mocks/build.func"

test_my_feature() {
    MOCK_CALLS=()
    MOCK_MODE="silent"

    # Your test code
    msg_info "Testing"

    # Check results
    if [[ "${MOCK_CALLS[*]}" == *"msg_info"* ]]; then
        echo "PASS"
    else
        echo "FAIL"
        exit 1
    fi
}

test_my_feature
```

## What Gets Tested

### CT Script Tests
- Required variables exist (APP, var_cpu, var_ram, etc.)
- update_script function exists
- Script sources build.func
- Mock functions work correctly

### Install Script Tests
- All setup functions are callable
- Network check behavior
- Mock apt-get/systemctl work
- Script syntax validation

### JSON Config Tests
- Valid JSON syntax
- Required fields present
- Values match ct script
- URL formats correct

## Requirements

- Bash 4.0+
- python3 (optional, for JSON validation)
- jq (optional fallback for JSON validation)
