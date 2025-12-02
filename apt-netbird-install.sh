#!/bin/sh
# NetBird installer for headless Debian/Ubuntu (apt-based) systems from root user
# Simplified from: https://pkgs.netbird.io/install.sh
set -e

# Check if apt is available
if ! command -v apt > /dev/null; then
    echo "Error: apt not found. This script is for Debian/Ubuntu systems only."
    exit 1
fi

echo "Installing NetBird using apt package manager..."

# Install dependencies
apt update
apt install ca-certificates curl gnupg -y

# Add NetBird GPG key
curl -sSL https://pkgs.netbird.io/debian/public.key \
    | gpg --dearmor -o /usr/share/keyrings/netbird-archive-keyring.gpg

chmod 0644 /usr/share/keyrings/netbird-archive-keyring.gpg

# Add NetBird repository
echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' \
    | tee /etc/apt/sources.list.d/netbird.list

# Update and install NetBird
apt update
apt install netbird -y

# Save installation method to config
mkdir -p /etc/netbird
echo "package_manager=apt" | tee /etc/netbird/install.conf > /dev/null

# Install and start the service
if ! netbird service install 2>&1; then
    echo "NetBird service has already been loaded"
fi

if ! netbird service start 2>&1; then
    echo "NetBird service has already been started"
fi

echo "Installation complete!
