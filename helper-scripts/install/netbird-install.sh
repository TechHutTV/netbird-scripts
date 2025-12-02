#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: TechHutTV
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://netbird.io/

# Support test mode by allowing local mock to be sourced instead of FUNCTIONS_FILE_PATH
if [[ "${TEST_MODE:-}" == "true" ]] && [[ -n "${MOCK_INSTALL_FUNC:-}" ]]; then
    source "$MOCK_INSTALL_FUNC"
else
    source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
fi
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    curl \
    ca-certificates \
    gnupg
msg_ok "Installed Dependencies"

msg_info "Installing NetBird"
$STD curl -fsSL https://pkgs.netbird.io/install.sh | sh
msg_ok "Installed NetBird"

msg_info "Enabling NetBird Service"
$STD systemctl enable netbird
msg_ok "Enabled NetBird Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
