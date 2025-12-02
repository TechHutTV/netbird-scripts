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
    echo -e "${CYAN}"
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

# Display configuration summary
show_summary() {
    local vmid="$1"

    echo ""
    echo -e "${BOLD}Configuration Summary${NC}"
    echo "═════════════════════════════════════════"
    echo -e "  VMID:        ${CYAN}${vmid}${NC}"
    echo -e "  Hostname:    ${CYAN}${HOSTNAME}${NC}"
    echo -e "  OS:          ${CYAN}Debian ${DEBIAN_VERSION}${NC}"
    echo -e "  Storage:     ${CYAN}${DEFAULT_STORAGE} GB${NC}"
    echo -e "  RAM:         ${CYAN}${DEFAULT_RAM} MB${NC}"
    echo -e "  CPU:         ${CYAN}${DEFAULT_CPU} core(s)${NC}"
    echo -e "  Network:     ${CYAN}DHCP (${DEFAULT_BRIDGE})${NC}"
    echo -e "  Type:        ${CYAN}Unprivileged${NC}"
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

    # Build the pct create command
    if ! pct create "$vmid" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
        --hostname "$HOSTNAME" \
        --password "$ROOT_PASSWORD" \
        --ostype debian \
        --cores "$DEFAULT_CPU" \
        --memory "$DEFAULT_RAM" \
        --swap 512 \
        --rootfs "${CONTAINER_STORAGE}:${DEFAULT_STORAGE}" \
        --net0 "name=eth0,bridge=${DEFAULT_BRIDGE},ip=dhcp,type=veth" \
        --unprivileged 1 \
        --features "nesting=1,keyctl=1" \
        --onboot 0 \
        --start 0; then
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

    msg_info "Updating container packages..."
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

# Display final information
show_completion() {
    local vmid="$1"

    echo ""
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║              Container Created Successfully!                      ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}Container Details:${NC}"
    echo "─────────────────────────────────────────"
    echo -e "  VMID:        ${CYAN}${vmid}${NC}"
    echo -e "  Hostname:    ${CYAN}${HOSTNAME}${NC}"
    echo -e "  IP Address:  ${CYAN}${CONTAINER_IP}${NC}"
    echo -e "  OS:          ${CYAN}Debian ${DEBIAN_VERSION}${NC}"
    echo ""
    echo -e "${BOLD}Access your container:${NC}"
    echo -e "  Console:     ${YELLOW}pct enter ${vmid}${NC}"
    echo -e "  SSH:         ${YELLOW}ssh root@${CONTAINER_IP}${NC}"
    echo ""
    echo -e "${BOLD}Container Management:${NC}"
    echo -e "  Start:       ${YELLOW}pct start ${vmid}${NC}"
    echo -e "  Stop:        ${YELLOW}pct stop ${vmid}${NC}"
    echo -e "  Destroy:     ${YELLOW}pct destroy ${vmid}${NC}"
    echo ""
    echo -e "${BOLD}Netbird Commands:${NC}"
    echo -e "  Status:      ${YELLOW}netbird status${NC}"
    echo -e "  Connect:     ${YELLOW}netbird up${NC}"
    echo -e "  Disconnect:  ${YELLOW}netbird down${NC}"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  Netbird is installed and ready. Run 'netbird up' inside the"
    echo "  container to connect to your Netbird network."
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

    # Get next available VMID
    VMID=$(get_next_vmid)

    # Show summary and confirm
    show_summary "$VMID"

    # Create container and configure for Netbird
    create_container "$VMID"
    configure_lxc_tun "$VMID"

    # Start container
    start_container "$VMID"

    # Get container IP
    get_container_ip "$VMID"

    # Update container and install Netbird
    setup_netbird "$VMID"

    # Show completion message
    show_completion "$VMID"
}

# Run main function
main "$@"
