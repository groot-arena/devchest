#!/usr/bin/env bash
# DevChest RHEL/CentOS/Fedora helpers. Source after lib/common.sh.
# Provides: dc_yum_or_dnf_*, dc_is_rhel, dc_is_centos, dc_is_fedora.

set -euo pipefail

dc_is_rhel() {
  [[ "${OS_ID:-}" == "rhel" ]]
}

dc_is_centos() {
  [[ "${OS_ID:-}" == "centos" ]]
}

dc_is_fedora() {
  [[ "${OS_ID:-}" == "fedora" ]]
}

_dc_package_manager() {
  if dc_check_command dnf; then
    echo "dnf"
  elif dc_check_command yum; then
    echo "yum"
  else
    dc_die "Neither dnf nor yum found. Cannot install packages."
  fi
}

dc_yum_or_dnf_update_cache() {
  local pm
  pm="$(_dc_package_manager)"
  dc_log_verbose "Running ${pm} check-update or update"
  if [[ "${pm}" == "dnf" ]]; then
    dnf check-update -q || true
  else
    yum check-update -q || true
  fi
}

dc_yum_or_dnf_install() {
  local pm
  pm="$(_dc_package_manager)"
  dc_log_info "Installing packages via ${pm}: $*"
  if [[ "${pm}" == "dnf" ]]; then
    dnf install -y -q "$@"
  else
    yum install -y -q "$@"
  fi
}

dc_yum_or_dnf_remove() {
  local pm
  pm="$(_dc_package_manager)"
  dc_log_info "Removing packages via ${pm}: $*"
  if [[ "${pm}" == "dnf" ]]; then
    dnf remove -y -q "$@"
  else
    yum remove -y -q "$@"
  fi
}
