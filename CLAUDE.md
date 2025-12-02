# CLAUDE.md - AI Assistant Guide for netbird-scripts

## Repository Overview

This repository contains automation scripts for [Netbird](https://netbird.io/), an open-source VPN management platform. The primary focus is on Proxmox VE integration, providing scripts to automate the deployment of Netbird infrastructure.

## Project Structure

```
netbird-scripts/
├── CLAUDE.md              # This file - AI assistant guidance
├── README.md              # Project documentation
├── LICENSE                # GPL-3.0 license
└── netbird-pve-lxc.sh     # Main script: LXC container creation for Proxmox VE
```

## Primary Script: netbird-pve-lxc.sh

### Purpose
Creates a Debian-based LXC container on Proxmox VE hosts optimized for running Netbird. The script handles template management, storage detection, user configuration, and container provisioning.

### Default Container Specifications
- **OS**: Debian 13 (Trixie) with fallback to Debian 12 (Bookworm)
- **Storage**: 8 GB
- **RAM**: 512 MB
- **CPU**: 1 core
- **Network**: DHCP via vmbr0 bridge
- **Type**: Unprivileged with nesting and keyctl enabled

### Script Architecture

The script follows a modular design with these sections:

1. **Configuration Defaults** (lines 22-28): Hardcoded default values
2. **Color Definitions** (lines 31-37): Terminal output styling
3. **Helper Functions** (lines 42-70): `msg_info`, `msg_ok`, `msg_warn`, `msg_error`, `header`
4. **Pre-flight Checks** (lines 73-96): `check_proxmox`, `check_root`, `get_next_vmid`
5. **Storage Detection** (lines 99-136): `detect_storage`, `detect_template_storage`
6. **Template Management** (lines 139-180): `download_template`
7. **User Input** (lines 183-255): `get_hostname`, `get_password`, `show_summary`
8. **Container Operations** (lines 258-329): `create_container`, `start_container`, `get_container_ip`
9. **Output Display** (lines 332-363): `show_completion`
10. **Main Execution** (lines 369-405): `main` function orchestrating all operations

### Key Functions Reference

| Function | Line | Description |
|----------|------|-------------|
| `msg_info` | 43 | Blue info message |
| `msg_ok` | 47 | Green success message |
| `msg_warn` | 51 | Yellow warning message |
| `msg_error` | 55 | Red error message |
| `header` | 59 | ASCII art banner display |
| `check_proxmox` | 73 | Verify running on PVE host |
| `check_root` | 84 | Verify root privileges |
| `get_next_vmid` | 92 | Get next available container ID |
| `detect_storage` | 99 | Find container storage (rootdir) |
| `detect_template_storage` | 127 | Find template storage (vztmpl) |
| `download_template` | 139 | Download/verify Debian template |
| `get_hostname` | 183 | Prompt for container hostname |
| `get_password` | 204 | Secure password input with confirmation |
| `show_summary` | 231 | Display configuration before creation |
| `create_container` | 258 | Execute pct create command |
| `start_container` | 285 | Start container and verify |
| `get_container_ip` | 306 | Wait for and retrieve DHCP IP |
| `show_completion` | 332 | Display final success information |

## Development Conventions

### Shell Scripting Standards

1. **Strict Mode**: All scripts use `set -euo pipefail` for robust error handling
   - `-e`: Exit on any command failure
   - `-u`: Error on undefined variables
   - `-o pipefail`: Pipeline fails if any command fails

2. **Shebang**: Use `#!/usr/bin/env bash` for portability

3. **Variable Declarations**:
   - Use `local` for function-scoped variables
   - UPPERCASE for global/configuration variables
   - lowercase for local variables

4. **Quoting**: Always quote variables to prevent word splitting: `"$variable"`

5. **Command Substitution**: Use `$(command)` instead of backticks

6. **Conditionals**: Use `[[ ]]` for tests (bash-specific, more robust)

7. **Error Handling**: Redirect errors appropriately with `2>/dev/null` or `|| true` when failure is acceptable

### Output Conventions

- Use colored output functions (`msg_info`, `msg_ok`, `msg_warn`, `msg_error`) for user feedback
- Prefix messages with type: `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`
- Use ASCII box drawing characters for headers and summaries

### Proxmox VE API Usage

The script uses standard PVE CLI tools:
- `pveversion` - Check PVE installation
- `pvesh` - PVE API shell interface
- `pvesm` - Storage management
- `pveam` - Appliance/template management
- `pct` - Container management (create, start, stop, exec, etc.)

## Testing Guidelines

### Manual Testing
Since this script requires Proxmox VE, testing must be done on an actual PVE host:

1. **Syntax Check**: `bash -n netbird-pve-lxc.sh`
2. **ShellCheck**: `shellcheck netbird-pve-lxc.sh`
3. **Dry Run**: Review script logic before execution
4. **Full Test**: Run on a test PVE environment

### Pre-Commit Checklist
- [ ] Script passes `shellcheck` without errors
- [ ] Script passes `bash -n` syntax check
- [ ] All functions have consistent error handling
- [ ] User inputs are validated
- [ ] Cleanup logic exists for failure cases

## Adding New Scripts

When adding new scripts to this repository:

1. **Header Block**: Include descriptive comment block at top:
   ```bash
   # =============================================================================
   # Script Name and Purpose
   # =============================================================================
   # Description of what the script does
   #
   # Usage: How to run it
   # =============================================================================
   ```

2. **Follow Existing Patterns**:
   - Reuse helper functions for messaging
   - Use the same color scheme
   - Include pre-flight checks
   - Add confirmation prompts for destructive operations

3. **Documentation**: Update README.md with new script documentation

## Common Tasks for AI Assistants

### When Modifying Scripts

1. Preserve the existing code style and patterns
2. Maintain backward compatibility with current PVE versions
3. Keep the interactive user experience consistent
4. Test changes with `shellcheck` before committing

### When Adding Features

1. Add new configuration variables to the defaults section
2. Create modular functions following existing naming conventions
3. Update the show_summary function if new user-visible options are added
4. Ensure proper error handling for all new operations

### Debugging Tips

- Add `set -x` temporarily for verbose execution tracing
- Use `msg_info "Debug: $variable"` for variable inspection
- Check PVE logs: `/var/log/pve/tasks/`

## External Resources

- [Netbird Documentation](https://docs.netbird.io/)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [ShellCheck](https://www.shellcheck.net/) - Shell script analysis tool

## License

This project is licensed under GPL-3.0. See LICENSE file for details. All contributions must be compatible with this license.
