#!/usr/bin/env bash

# Support test mode by allowing local mock to be sourced instead of remote URL
if [[ "${TEST_MODE:-}" == "true" ]] && [[ -n "${MOCK_BUILD_FUNC:-}" ]]; then
    source "$MOCK_BUILD_FUNC"
else
    source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
fi
# Copyright (c) 2021-2025 community-scripts ORG
# Author: TechHutTV
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://netbird.io/

APP="NetBird"
var_tags="network;vpn"
var_cpu="1"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="13"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -f /etc/netbird/config.json ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    msg_info "Updating ${APP}"
    $STD apt-get update
    $STD apt-get -y upgrade
    msg_ok "Updated Successfully"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access NetBird by entering the container and running:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}netbird up${CL}"
