#!/usr/bin/env bash

# =============================================================================
# Netbird LXC Container Creation Script for Proxmox VE
# =============================================================================
# This script creates a Debian 13 (Trixie) LXC container for running Netbird
#
# Default Specifications:
#   - OS: Debian 13 (Trixie) or Debian 12 (Bookworm) fallback
#   - Storage: 8 GB
#   - RAM: 512 MB
#   - CPU: 1 core
#   - Network: DHCP
#
# Usage: Run this script on your Proxmox VE host
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration Defaults
# -----------------------------------------------------------------------------
DEFAULT_STORAGE="8"        # GB
DEFAULT_RAM="512"          # MB
DEFAULT_CPU="1"            # Cores
DEFAULT_BRIDGE="vmbr0"     # Network bridge
TEMPLATE_STORAGE="local"   # Where to store templates
CONTAINER_STORAGE="local-lvm"  # Where to store container (will be auto-detected)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    clear
    echo -e "${ORANGE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║           Netbird LXC Container Creation Script                   ║"
    echo "║                     for Proxmox VE                                ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Check if running on Proxmox VE
check_proxmox() {
    if ! command -v pveversion &>/dev/null; then
        msg_error "This script must be run on a Proxmox VE host!"
        exit 1
    fi

    PVE_VERSION=$(pveversion --verbose | grep "^pve-manager" | awk '{print $2}' | cut -d'/' -f1)
    msg_ok "Proxmox VE detected: version ${PVE_VERSION}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root!"
        exit 1
    fi
}

# Get next available VMID
get_next_vmid() {
    local next_id
    next_id=$(pvesh get /cluster/nextid)
    echo "$next_id"
}

# Detect available storage for containers
detect_storage() {
    msg_info "Detecting available storage..."

    # Get storage that supports rootdir (container storage)
    local storages
    storages=$(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 {print $1}' | head -1)

    if [[ -z "$storages" ]]; then
        # Fallback to checking for common storage names
        if pvesm status | grep -q "local-lvm"; then
            storages="local-lvm"
        elif pvesm status | grep -q "local-zfs"; then
            storages="local-zfs"
        elif pvesm status | grep -q "local"; then
            storages="local"
        fi
    fi

    if [[ -z "$storages" ]]; then
        msg_error "No suitable storage found for containers!"
        exit 1
    fi

    CONTAINER_STORAGE="$storages"
    msg_ok "Using storage: ${CONTAINER_STORAGE}"
}

# Detect template storage
detect_template_storage() {
    local storages
    storages=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}' | head -1)

    if [[ -n "$storages" ]]; then
        TEMPLATE_STORAGE="$storages"
    fi

    msg_ok "Template storage: ${TEMPLATE_STORAGE}"
}

# Check and download Debian template
download_template() {
    msg_info "Updating template database..."
    pveam update &>/dev/null || true

    # First, try to find Debian 13 (Trixie) template
    local template_13
    template_13=$(pveam available --section system 2>/dev/null | grep -E "debian-13" | awk '{print $2}' | head -1 || true)

    if [[ -n "$template_13" ]]; then
        TEMPLATE="$template_13"
        DEBIAN_VERSION="13"
        msg_ok "Found Debian 13 (Trixie) template: ${TEMPLATE}"
    else
        # Fallback to Debian 12 (Bookworm)
        msg_warn "Debian 13 template not yet available in official repository"
        msg_info "Falling back to Debian 12 (Bookworm)..."

        local template_12
        template_12=$(pveam available --section system 2>/dev/null | grep -E "debian-12" | awk '{print $2}' | head -1 || true)

        if [[ -n "$template_12" ]]; then
            TEMPLATE="$template_12"
            DEBIAN_VERSION="12"
            msg_ok "Found Debian 12 (Bookworm) template: ${TEMPLATE}"
        else
            msg_error "No suitable Debian template found!"
            exit 1
        fi
    fi

    # Check if template is already downloaded
    if pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "$TEMPLATE"; then
        msg_ok "Template already downloaded"
    else
        msg_info "Downloading template: ${TEMPLATE}..."
        if ! pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"; then
            msg_error "Failed to download template!"
            exit 1
        fi
        msg_ok "Template downloaded successfully"
    fi
}

# Get user input for hostname
get_hostname() {
    echo ""
    echo -e "${BOLD}Container Configuration${NC}"
    echo "─────────────────────────────────────────"
    echo ""

    local default_hostname="netbird"
    read -rp "Enter hostname [${default_hostname}]: " HOSTNAME
    HOSTNAME="${HOSTNAME:-$default_hostname}"

    # Validate hostname (alphanumeric and hyphens only, max 63 chars)
    if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        msg_error "Invalid hostname! Use only letters, numbers, and hyphens."
        msg_error "Must start and end with alphanumeric, max 63 characters."
        exit 1
    fi

    msg_ok "Hostname: ${HOSTNAME}"
}

# Get user input for root password
get_password() {
    echo ""
    local password_confirmed=false

    while [[ "$password_confirmed" != "true" ]]; do
        read -rsp "Enter root password: " ROOT_PASSWORD
        echo ""

        if [[ ${#ROOT_PASSWORD} -lt 5 ]]; then
            msg_error "Password must be at least 5 characters!"
            continue
        fi

        read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo ""

        if [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
            msg_error "Passwords do not match! Please try again."
        else
            password_confirmed=true
        fi
    done

    msg_ok "Root password set"
}

# Get advanced container settings
get_advanced_settings() {
    local next_vmid="$1"

    echo ""
    echo -e "${BOLD}Advanced Settings${NC}"
    echo "─────────────────────────────────────────"
    echo "Press Enter to accept defaults shown in brackets."
    echo ""

    # VMID
    read -rp "VMID [${next_vmid}]: " input_vmid
    CONTAINER_VMID="${input_vmid:-$next_vmid}"

    # Validate VMID is a number
    if [[ ! "$CONTAINER_VMID" =~ ^[0-9]+$ ]]; then
        msg_error "Invalid VMID! Must be a number."
        exit 1
    fi

    # Check if VMID is already in use
    if pct status "$CONTAINER_VMID" &>/dev/null; then
        msg_error "VMID ${CONTAINER_VMID} is already in use!"
        exit 1
    fi

    # Disk size
    read -rp "Disk size in GB [${DEFAULT_STORAGE}]: " input_disk
    CONTAINER_DISK="${input_disk:-$DEFAULT_STORAGE}"

    if [[ ! "$CONTAINER_DISK" =~ ^[0-9]+$ ]]; then
        msg_error "Invalid disk size! Must be a number."
        exit 1
    fi

    # RAM
    read -rp "RAM in MB [${DEFAULT_RAM}]: " input_ram
    CONTAINER_RAM="${input_ram:-$DEFAULT_RAM}"

    if [[ ! "$CONTAINER_RAM" =~ ^[0-9]+$ ]]; then
        msg_error "Invalid RAM size! Must be a number."
        exit 1
    fi

    # CPU cores
    read -rp "CPU cores [${DEFAULT_CPU}]: " input_cpu
    CONTAINER_CPU="${input_cpu:-$DEFAULT_CPU}"

    if [[ ! "$CONTAINER_CPU" =~ ^[0-9]+$ ]]; then
        msg_error "Invalid CPU count! Must be a number."
        exit 1
    fi

    # Container type
    echo ""
    echo "Container type:"
    echo "  1) Unprivileged (recommended, more secure)"
    echo "  2) Privileged (less secure, but simpler device access)"
    read -rp "Select type [1]: " input_type
    input_type="${input_type:-1}"

    case "$input_type" in
        1)
            CONTAINER_TYPE="unprivileged"
            ;;
        2)
            CONTAINER_TYPE="privileged"
            ;;
        *)
            msg_error "Invalid selection! Choose 1 or 2."
            exit 1
            ;;
    esac

    echo ""
    msg_ok "Advanced settings configured"
}

# Ask user for default or advanced settings
get_settings_mode() {
    local next_vmid="$1"

    echo ""
    echo "Would you like to use default settings or configure advanced options?"
    echo ""
    echo "  1) Default settings (recommended)"
    echo "  2) Advanced setup"
    echo ""
    read -rp "Select option [1]: " SETTINGS_CHOICE
    SETTINGS_CHOICE="${SETTINGS_CHOICE:-1}"

    case "$SETTINGS_CHOICE" in
        1)
            SETTINGS_MODE="default"
            CONTAINER_VMID="$next_vmid"
            CONTAINER_DISK="$DEFAULT_STORAGE"
            CONTAINER_RAM="$DEFAULT_RAM"
            CONTAINER_CPU="$DEFAULT_CPU"
            CONTAINER_TYPE="unprivileged"
            msg_ok "Using default settings"
            ;;
        2)
            SETTINGS_MODE="advanced"
            get_advanced_settings "$next_vmid"
            ;;
        *)
            msg_error "Invalid selection! Choose 1 or 2."
            exit 1
            ;;
    esac
}

# Display configuration summary
show_summary() {
    local vmid="$1"

    # Format container type for display
    local type_display="Unprivileged"
    if [[ "$CONTAINER_TYPE" == "privileged" ]]; then
        type_display="Privileged"
    fi

    # Format settings mode for display
    local settings_display="default"
    if [[ "$SETTINGS_MODE" == "advanced" ]]; then
        settings_display="advanced setup"
    fi

    echo ""
    echo -e "${BOLD}Configuration Summary (${settings_display})${NC}"
    echo "═════════════════════════════════════════"
    echo -e "  VMID:        ${CYAN}${vmid}${NC}"
    echo -e "  Hostname:    ${CYAN}${HOSTNAME}${NC}"
    echo -e "  OS:          ${CYAN}Debian ${DEBIAN_VERSION}${NC}"
    echo -e "  Disk:        ${CYAN}${CONTAINER_DISK} GB${NC}"
    echo -e "  RAM:         ${CYAN}${CONTAINER_RAM} MB${NC}"
    echo -e "  CPU:         ${CYAN}${CONTAINER_CPU} core(s)${NC}"
    echo -e "  Network:     ${CYAN}DHCP (${DEFAULT_BRIDGE})${NC}"
    echo -e "  Type:        ${CYAN}${type_display}${NC}"
    echo "═════════════════════════════════════════"
    echo ""

    read -rp "Proceed with container creation? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        msg_warn "Container creation cancelled."
        exit 0
    fi
}

# Create the LXC container
create_container() {
    local vmid="$1"

    msg_info "Creating LXC container (VMID: ${vmid})..."

    # Build the pct create command based on container type
    local unprivileged_flag="1"
    local features="nesting=1,keyctl=1"

    if [[ "$CONTAINER_TYPE" == "privileged" ]]; then
        unprivileged_flag="0"
        features="nesting=1"
    fi

    # Run pct create and suppress verbose extraction output
    if ! pct create "$vmid" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
        --hostname "$HOSTNAME" \
        --password "$ROOT_PASSWORD" \
        --ostype debian \
        --cores "$CONTAINER_CPU" \
        --memory "$CONTAINER_RAM" \
        --swap 512 \
        --rootfs "${CONTAINER_STORAGE}:${CONTAINER_DISK}" \
        --net0 "name=eth0,bridge=${DEFAULT_BRIDGE},ip=dhcp,type=veth" \
        --unprivileged "$unprivileged_flag" \
        --features "$features" \
        --onboot 0 \
        --start 0 &>/dev/null; then
        msg_error "Failed to create container!"
        exit 1
    fi

    msg_ok "Container created successfully"
}

# Configure LXC for TUN device support (required for Netbird VPN)
configure_lxc_tun() {
    local vmid="$1"
    local config_file="/etc/pve/lxc/${vmid}.conf"

    msg_info "Configuring TUN device support for Netbird..."

    # Add LXC config entries for TUN device
    {
        echo ""
        echo "# Netbird TUN device configuration"
        echo "lxc.cgroup2.devices.allow: c 10:200 rwm"
        echo "lxc.mount.entry: /dev/net dev/net none bind,create=dir"
        echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"
    } >> "$config_file"

    msg_ok "TUN device configuration added"
}

# Start the container
start_container() {
    local vmid="$1"

    msg_info "Starting container..."
    if ! pct start "$vmid"; then
        msg_error "Failed to start container!"
        exit 1
    fi

    # Wait for container to fully start
    sleep 3

    # Check if container is running
    if pct status "$vmid" | grep -q "running"; then
        msg_ok "Container is running"
    else
        msg_warn "Container may not have started properly"
    fi
}

# Get container IP address
get_container_ip() {
    local vmid="$1"
    local max_attempts=10
    local attempt=1

    msg_info "Waiting for network configuration..."

    while [[ $attempt -le $max_attempts ]]; do
        local ip
        ip=$(pct exec "$vmid" -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

        if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
            CONTAINER_IP="$ip"
            msg_ok "Container IP: ${CONTAINER_IP}"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    msg_warn "Could not determine container IP address"
    CONTAINER_IP="(pending DHCP)"
}

# Update container and install Netbird
setup_netbird() {
    local vmid="$1"

    msg_info "Updating container packages (this may take a few minutes)..."
    if ! pct exec "$vmid" -- bash -c "apt update && apt upgrade -y && apt install curl -y" &>/dev/null; then
        msg_error "Failed to update container packages!"
        exit 1
    fi
    msg_ok "Container packages updated"

    msg_info "Installing Netbird..."
    if ! pct exec "$vmid" -- bash -c "curl -fsSL https://pkgs.netbird.io/install.sh | sh" &>/dev/null; then
        msg_error "Failed to install Netbird!"
        exit 1
    fi
    msg_ok "Netbird installed successfully"
}

# Get Netbird authentication method from user
get_auth_method() {
    echo ""
    echo -e "${BOLD}Netbird Setup${NC}"
    echo "─────────────────────────────────────────"
    echo "Choose how to connect to your Netbird network:"
    echo ""
    echo "  1) Setup Key (default) - Use a pre-generated setup key"
    echo "  2) SSO Login - Authenticate via browser with your identity provider"
    echo ""

    read -rp "Select authentication method [1]: " AUTH_METHOD
    AUTH_METHOD="${AUTH_METHOD:-1}"

    case "$AUTH_METHOD" in
        1)
            AUTH_TYPE="setup_key"
            get_setup_key
            ;;
        2)
            AUTH_TYPE="sso"
            msg_ok "SSO login selected"
            ;;
        *)
            msg_error "Invalid selection! Choose 1 or 2."
            exit 1
            ;;
    esac
}

# Get Netbird setup key from user
get_setup_key() {
    echo ""
    echo "Enter your Netbird setup key to connect this container to your network."
    echo "You can find this in your Netbird dashboard under Setup Keys."
    echo ""

    read -rp "Setup key: " NETBIRD_SETUP_KEY
    echo ""

    if [[ -z "$NETBIRD_SETUP_KEY" ]]; then
        msg_error "Setup key is required!"
        exit 1
    fi

    # Confirm the setup key before proceeding
    echo -e "Setup key: ${CYAN}${NETBIRD_SETUP_KEY}${NC}"
    read -rp "Press Enter to continue or Ctrl+C to cancel..."

    msg_ok "Setup key confirmed"
}

# Connect to Netbird using setup key
connect_netbird_key() {
    local vmid="$1"

    msg_info "Connecting to Netbird network with setup key..."

    # Run netbird up with the setup key
    if ! pct exec "$vmid" -- netbird up -k "$NETBIRD_SETUP_KEY" &>/dev/null; then
        msg_error "Failed to initiate Netbird connection!"
        exit 1
    fi
}

# Connect to Netbird using SSO login
connect_netbird_sso() {
    local vmid="$1"

    echo ""
    echo -e "${BOLD}SSO Authentication${NC}"
    echo "─────────────────────────────────────────"
    echo "A login URL will appear below."
    echo "Copy the URL and open it in your browser to authenticate."
    echo ""
    echo -e "${YELLOW}Waiting for login URL (this may take a few seconds)...${NC}"
    echo ""

    # Run netbird login directly without command substitution
    # This allows the URL to stream to the terminal in real-time
    # The command will block until authentication is complete in the browser
    pct exec "$vmid" -- netbird login 2>&1 || true

    echo ""
    msg_ok "SSO authentication completed"

    msg_info "Connecting to Netbird network..."

    # Run netbird up to establish the connection
    if ! pct exec "$vmid" -- netbird up &>/dev/null; then
        msg_error "Failed to connect to Netbird!"
        exit 1
    fi
}

# Connect to Netbird and wait for confirmation
connect_netbird() {
    local vmid="$1"
    local max_attempts=30
    local attempt=1

    # Use appropriate connection method based on auth type
    if [[ "$AUTH_TYPE" == "sso" ]]; then
        connect_netbird_sso "$vmid"
    else
        connect_netbird_key "$vmid"
    fi

    msg_info "Waiting for Netbird connection..."

    # Wait for connection to be established
    while [[ $attempt -le $max_attempts ]]; do
        local status
        status=$(pct exec "$vmid" -- netbird status 2>/dev/null || true)

        if echo "$status" | grep -q "Connected"; then
            msg_ok "Netbird connected successfully"

            # Extract Netbird IP
            NETBIRD_IP=$(echo "$status" | grep -oP 'NetBird IP:\s*\K[\d./]+' || echo "N/A")
            NETBIRD_FQDN=$(echo "$status" | grep -oP 'FQDN:\s*\K\S+' || echo "N/A")

            return 0
        fi

        sleep 2
        ((attempt++))
    done

    msg_warn "Connection taking longer than expected. Check status with 'netbird status'"
    NETBIRD_IP="(pending)"
    NETBIRD_FQDN="(pending)"
}

# Get full Netbird status for display
get_netbird_status() {
    local vmid="$1"

    NETBIRD_STATUS=$(pct exec "$vmid" -- netbird status 2>/dev/null || echo "Unable to retrieve status")
}

# Display final information
show_completion() {
    local vmid="$1"

    echo ""
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║           Netbird Container Setup Complete!                       ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}Netbird Connection Status:${NC}"
    echo "─────────────────────────────────────────"
    echo -e "  Netbird IP:  ${CYAN}${NETBIRD_IP}${NC}"
    echo -e "  FQDN:        ${CYAN}${NETBIRD_FQDN}${NC}"
    echo -e "  Hostname:    ${CYAN}${HOSTNAME}${NC}"
    echo -e "  Container:   ${CYAN}${CONTAINER_IP}${NC}"
    echo ""
    echo -e "${BOLD}Full Netbird Status:${NC}"
    echo "─────────────────────────────────────────"
    echo "$NETBIRD_STATUS"
    echo ""
    echo -e "${BOLD}Netbird Commands (run inside container):${NC}"
    echo "─────────────────────────────────────────"
    echo -e "  ${YELLOW}netbird status${NC}          Show connection status and peers"
    echo -e "  ${YELLOW}netbird status -d${NC}       Show detailed status with routes"
    echo -e "  ${YELLOW}netbird down${NC}            Disconnect from Netbird network"
    echo -e "  ${YELLOW}netbird up${NC}              Reconnect to Netbird network"
    echo -e "  ${YELLOW}netbird ssh${NC}             SSH to a peer via Netbird"
    echo ""
    echo -e "${BOLD}Access Container:${NC}"
    echo -e "  ${YELLOW}pct enter ${vmid}${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

main() {
    header

    # Pre-flight checks
    check_root
    check_proxmox

    # Detect storage options
    detect_storage
    detect_template_storage

    # Download/verify template
    download_template

    # Get user configuration
    get_hostname
    get_password

    # Get next available VMID for default suggestion
    local next_vmid
    next_vmid=$(get_next_vmid)

    # Ask for default or advanced settings
    get_settings_mode "$next_vmid"

    # Show summary and confirm
    show_summary "$CONTAINER_VMID"

    # Create container
    create_container "$CONTAINER_VMID"

    # Configure TUN device only for unprivileged containers
    if [[ "$CONTAINER_TYPE" == "unprivileged" ]]; then
        configure_lxc_tun "$CONTAINER_VMID"
    fi

    # Start container
    start_container "$CONTAINER_VMID"

    # Get container IP
    get_container_ip "$CONTAINER_VMID"

    # Update container and install Netbird
    setup_netbird "$CONTAINER_VMID"

    # Get Netbird authentication method from user
    get_auth_method

    # Connect to Netbird and wait for confirmation
    connect_netbird "$CONTAINER_VMID"

    # Get full Netbird status for display
    get_netbird_status "$CONTAINER_VMID"

    # Show completion message
    show_completion "$CONTAINER_VMID"
}

# Run main function
main "$@"
