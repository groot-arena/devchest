#!/usr/bin/env bash
set -euo pipefail
# DevChest tool: Node Version Manager (nvm)
# Requires: lib/common.sh; install is script-based, no packages required for nvm itself.

export TOOL_ID="nvm"
export TOOL_DISPLAY_NAME="Node Version Manager (nvm)"
export TOOL_DESCRIPTION="Install and switch Node.js versions"

export TOOL_CATEGORIES=("dev" "node")
export TOOL_CORE_COMMANDS=("nvm")
export TOOL_DEBIAN_PACKAGES=()
export TOOL_REDHAT_PACKAGES=()

install_nvm() {
  dc_log_info "Installing ${TOOL_DISPLAY_NAME}..."

  if [[ -n "${NVM_DIR:-}" ]] && [[ -f "${NVM_DIR}/nvm.sh" ]]; then
    dc_log_info "nvm is already installed at ${NVM_DIR}."
    return 0
  fi

  if dc_check_command nvm 2>/dev/null; then
    dc_log_info "nvm is already available."
    return 0
  fi

  local nvm_version="v0.40.1"
  local api_json
  if dc_check_command curl; then
    api_json="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null)" || true
  elif dc_check_command wget; then
    api_json="$(wget -qO- https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null)" || true
  fi
  if [[ -n "${api_json}" ]]; then
    nvm_version="$(echo "${api_json}" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
  [[ -z "${nvm_version}" ]] && nvm_version="v0.40.1"
  dc_log_verbose "Using nvm version: ${nvm_version}"

  local install_script
  if dc_check_command curl; then
    install_script="$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh")"
  elif dc_check_command wget; then
    install_script="$(wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh")"
  else
    dc_log_error "Need curl or wget to install nvm."
    return 1
  fi

  export NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"
  mkdir -p "${NVM_DIR}"
  echo "${install_script}" | bash 2>/dev/null || true
  # Make nvm available for all users: add to a profile.d script
  local profile_d="/etc/profile.d/devchest-nvm.sh"
  if [[ ! -f "${profile_d}" ]]; then
    echo "# DevChest: nvm" > "${profile_d}"
    echo "export NVM_DIR=\"${NVM_DIR}\"" >> "${profile_d}"
    echo "[[ -s \"\${NVM_DIR}/nvm.sh\" ]] && . \"\${NVM_DIR}/nvm.sh\"" >> "${profile_d}"
  fi
  dc_log_info "nvm installed. Source ${profile_d} or open a new shell to use nvm."
  return 0
}

uninstall_nvm() {
  dc_log_info "Uninstalling ${TOOL_DISPLAY_NAME}..."
  local profile_d="/etc/profile.d/devchest-nvm.sh"
  local nvm_dir="${NVM_DIR:-/usr/local/share/nvm}"
  rm -f "${profile_d}" 2>/dev/null || true
  if [[ -d "${nvm_dir}" ]]; then
    dc_log_info "Remove nvm directory manually if desired: rm -rf ${nvm_dir}"
  fi
  return 0
}

is_nvm_installed() {
  if [[ -n "${NVM_DIR:-}" ]] && [[ -f "${NVM_DIR}/nvm.sh" ]]; then
    return 0
  fi
  [[ -f /usr/local/share/nvm/nvm.sh ]] || [[ -f /etc/profile.d/devchest-nvm.sh ]]
}
