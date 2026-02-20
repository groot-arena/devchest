#!/usr/bin/env bash
# DevChest Debian/Ubuntu helpers. Source after lib/common.sh.
# Provides: dc_apt_update_cache, dc_apt_install, dc_apt_remove, dc_is_ubuntu, dc_is_debian.

set -euo pipefail

dc_is_ubuntu() {
  [[ "${OS_ID:-}" == "ubuntu" ]]
}

dc_is_debian() {
  [[ "${OS_ID:-}" == "debian" ]]
}

dc_apt_update_cache() {
  dc_log_verbose "Running apt-get update"
  apt-get update -qq
}

dc_apt_install() {
  dc_log_info "Installing packages: $*"
  apt-get install -y -qq "$@"
}

dc_apt_remove() {
  dc_log_info "Removing packages: $*"
  apt-get remove -y -qq "$@"
}
